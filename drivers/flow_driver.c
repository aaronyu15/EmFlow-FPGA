// SPDX-License-Identifier: GPL-2.0-only
/*
 * snn-flow-driver — Event camera pipeline + DMA frame capture for KV260
 *
 * Based on Prophesee psee-video composite driver.
 * Copyright (C) Prophesee S.A. (original psee-video)
 *
 * Modifications:
 *   - DMA client using kernel DMA engine API (replaces psee-dma/treuzell)
 *   - /dev/flow0 char device for reading flow frames
 *   - sysfs "stream" attribute starts both pipeline and DMA
 *   - Compatible string: "custom,snn-flow-driver"
 *
 * Each DMA transfer completes on TLAST from the accelerator.
 * Userspace reads variable-length frames via read() on /dev/flow0.
 *
 * Flow vector format (64 bits per vector):
 *   [63:36] = zeros
 *   [35:27] = fh_x  (9 bits, unsigned, 0..319)
 *   [26:18] = fh_y  (9 bits, unsigned, 0..319)
 *   [17:9]  = fh_u  (9 bits, signed)
 *   [8:0]   = fh_v  (9 bits, signed)
 *
 * Max frame: 320*320 vectors * 8 bytes = 819200 bytes
 */

#include <linux/list.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_graph.h>
#include <linux/platform_device.h>
#include <linux/slab.h>
#include <linux/of_reserved_mem.h>
#include <linux/cdev.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/wait.h>
#include <linux/poll.h>
#include <linux/dmaengine.h>
#include <linux/dma-mapping.h>

#include <media/v4l2-async.h>
#include <media/v4l2-common.h>
#include <media/v4l2-device.h>
#include <media/v4l2-fwnode.h>

/* ------------------------------------------------------------------ */
/*  Constants                                                         */
/* ------------------------------------------------------------------ */

#define DRIVER_NAME	"snn-flow-driver"
#define FLOW_DEV_NAME	"flow0"

/* DMA buffer configuration */
#define FLOW_N_BUFS	5		/* Number of ring buffers        */
#define FLOW_BUF_SIZE	(1024 * 1024)	/* 1MB per buffer (>= 800KB max) */

/* ------------------------------------------------------------------ */
/*  DMA buffer                                                        */
/* ------------------------------------------------------------------ */

struct flow_buf {
	void		*vaddr;		/* CPU virtual address            */
	dma_addr_t	 dma_addr;	/* DMA/bus address                */
	size_t		 size;		/* Allocated size                 */
	size_t		 bytesused;	/* Actual bytes transferred       */
	dma_cookie_t	 cookie;	/* DMA engine cookie              */
	struct list_head list;
};

/* ------------------------------------------------------------------ */
/*  Structs                                                           */
/* ------------------------------------------------------------------ */

struct psee_graph_entity {
	struct v4l2_async_subdev asd;	/* must be first */
	struct media_entity *entity;
	struct v4l2_subdev *subdev;
	bool streaming;
};

struct psee_composite_device {
	struct device		*dev;
	struct platform_device	*platform_dev;
	struct media_device	 media_dev;
	struct v4l2_device	 v4l2_dev;
	struct v4l2_async_notifier notifier;
	struct list_head	 dmas;		/* unused, kept for compat */
	u32			 v4l2_caps;
	bool			 streaming;

	/* DMA engine */
	struct dma_chan		*dma_chan;
	struct flow_buf		 bufs[FLOW_N_BUFS];

	struct list_head	 free_list;	/* Buffers ready for DMA  */
	struct list_head	 done_list;	/* Frames ready for read  */
	spinlock_t		 buf_lock;	/* Protects free/done     */
	struct flow_buf		*active;	/* Currently in DMA       */
	struct work_struct	 resubmit_work;	/* Deferred DMA resubmit  */
	unsigned long		 frames_done;	/* Total frames completed */
	unsigned long		 frames_dropped;/* Frames lost (no bufs)  */

	wait_queue_head_t	 read_wait;	/* Wake on frame ready    */

	/* Char device */
	dev_t			 devno;
	struct cdev		 cdev;
	struct class		*cls;
	struct device		*chrdev;
};

static inline struct psee_graph_entity *
to_psee_entity(struct v4l2_async_subdev *asd)
{
	return container_of(asd, struct psee_graph_entity, asd);
}

/* ------------------------------------------------------------------ */
/*  DMA buffer management                                             */
/* ------------------------------------------------------------------ */

static int flow_alloc_buffers(struct psee_composite_device *pdev)
{
	int i;

	INIT_LIST_HEAD(&pdev->free_list);
	INIT_LIST_HEAD(&pdev->done_list);

	for (i = 0; i < FLOW_N_BUFS; i++) {
		struct flow_buf *buf = &pdev->bufs[i];

		buf->size = FLOW_BUF_SIZE;
		buf->vaddr = dma_alloc_coherent(pdev->dev, buf->size,
						&buf->dma_addr, GFP_KERNEL);
		if (!buf->vaddr) {
			dev_err(pdev->dev, "failed to alloc DMA buf %d\n", i);
			goto err_free;
		}

		buf->bytesused = 0;
		INIT_LIST_HEAD(&buf->list);
		list_add_tail(&buf->list, &pdev->free_list);
	}

	dev_info(pdev->dev, "allocated %d x %d DMA buffers\n",
		 FLOW_N_BUFS, FLOW_BUF_SIZE);
	return 0;

err_free:
	while (--i >= 0) {
		dma_free_coherent(pdev->dev, pdev->bufs[i].size,
				  pdev->bufs[i].vaddr,
				  pdev->bufs[i].dma_addr);
		pdev->bufs[i].vaddr = NULL;
	}
	return -ENOMEM;
}

static void flow_free_buffers(struct psee_composite_device *pdev)
{
	int i;

	for (i = 0; i < FLOW_N_BUFS; i++) {
		if (pdev->bufs[i].vaddr) {
			dma_free_coherent(pdev->dev, pdev->bufs[i].size,
					  pdev->bufs[i].vaddr,
					  pdev->bufs[i].dma_addr);
			pdev->bufs[i].vaddr = NULL;
		}
	}
}

/* ------------------------------------------------------------------ */
/*  DMA engine transfer                                               */
/* ------------------------------------------------------------------ */

static void flow_dma_submit_next(struct psee_composite_device *pdev);

static void flow_resubmit_work_fn(struct work_struct *work)
{
	struct psee_composite_device *pdev =
		container_of(work, struct psee_composite_device, resubmit_work);
	unsigned long flags;

	if (!pdev->streaming)
		return;

	spin_lock_irqsave(&pdev->buf_lock, flags);
	if (!pdev->active && pdev->streaming)
		flow_dma_submit_next(pdev);
	spin_unlock_irqrestore(&pdev->buf_lock, flags);
}

static void flow_dma_callback(void *data,
			     const struct dmaengine_result *result)
{
	struct psee_composite_device *pdev = data;
	struct flow_buf *buf;
	unsigned long flags;

	spin_lock_irqsave(&pdev->buf_lock, flags);

	buf = pdev->active;
	if (!buf) {
		spin_unlock_irqrestore(&pdev->buf_lock, flags);
		dev_warn(pdev->dev, "DMA callback with no active buffer\n");
		return;
	}

	/* Get actual transfer length from residue provided by the
	 * Xilinx DMA driver via callback_result. This is the correct
	 * way to get the byte count for TLAST-terminated transfers.
	 */
	if (result && result->result == DMA_TRANS_NOERROR)
		buf->bytesused = FLOW_BUF_SIZE - result->residue;
	else
		buf->bytesused = FLOW_BUF_SIZE;

	if (buf->bytesused == 0)
		buf->bytesused = FLOW_BUF_SIZE; /* Fallback */

	/* Move to done list */
	pdev->active = NULL;
	list_add_tail(&buf->list, &pdev->done_list);
	pdev->frames_done++;

	spin_unlock_irqrestore(&pdev->buf_lock, flags);

	/* Wake any readers */
	wake_up_interruptible(&pdev->read_wait);

	/* Defer resubmission to process context */
	if (pdev->streaming)
		schedule_work(&pdev->resubmit_work);
}

static void flow_dma_submit_next(struct psee_composite_device *pdev)
{
	struct flow_buf *buf;
	struct dma_async_tx_descriptor *desc;

	/* Must be called with buf_lock held */

	if (pdev->active)
		return; /* Already have one in flight */

	if (list_empty(&pdev->free_list)) {
		dev_warn_ratelimited(pdev->dev, "no free DMA buffers\n");
		return;
	}

	buf = list_first_entry(&pdev->free_list, struct flow_buf, list);
	list_del_init(&buf->list);

	desc = dmaengine_prep_slave_single(pdev->dma_chan,
					   buf->dma_addr, buf->size,
					   DMA_DEV_TO_MEM,
					   DMA_PREP_INTERRUPT);
	if (!desc) {
		dev_err(pdev->dev, "prep_slave_single failed\n");
		list_add(&buf->list, &pdev->free_list);
		return;
	}

	desc->callback_result = flow_dma_callback;
	desc->callback_param = pdev;

	buf->cookie = dmaengine_submit(desc);
	if (dma_submit_error(buf->cookie)) {
		dev_err(pdev->dev, "dmaengine_submit failed\n");
		list_add(&buf->list, &pdev->free_list);
		return;
	}

	pdev->active = buf;
	dma_async_issue_pending(pdev->dma_chan);
}

static int flow_dma_start(struct psee_composite_device *pdev)
{
	struct dma_slave_config cfg = {
		.direction = DMA_DEV_TO_MEM,
		.src_addr_width = DMA_SLAVE_BUSWIDTH_8_BYTES, /* 64-bit stream */
	};
	unsigned long flags;
	int ret;

	ret = dmaengine_slave_config(pdev->dma_chan, &cfg);
	if (ret) {
		dev_err(pdev->dev, "slave_config failed: %d\n", ret);
		return ret;
	}

	spin_lock_irqsave(&pdev->buf_lock, flags);
	flow_dma_submit_next(pdev);
	spin_unlock_irqrestore(&pdev->buf_lock, flags);

	return pdev->active ? 0 : -EIO;
}

static void flow_dma_stop(struct psee_composite_device *pdev)
{
	unsigned long flags;

	cancel_work_sync(&pdev->resubmit_work);
	dmaengine_terminate_sync(pdev->dma_chan);

	spin_lock_irqsave(&pdev->buf_lock, flags);

	/* Return active buffer to free list */
	if (pdev->active) {
		list_add(&pdev->active->list, &pdev->free_list);
		pdev->active = NULL;
	}

	/* Return all done buffers to free list */
	while (!list_empty(&pdev->done_list)) {
		struct flow_buf *buf = list_first_entry(&pdev->done_list,
							struct flow_buf, list);
		list_del_init(&buf->list);
		list_add(&buf->list, &pdev->free_list);
	}

	spin_unlock_irqrestore(&pdev->buf_lock, flags);
}

/* ------------------------------------------------------------------ */
/*  Char device: /dev/flow0                                           */
/* ------------------------------------------------------------------ */

static int flow_open(struct inode *inode, struct file *file)
{
	struct psee_composite_device *pdev =
		container_of(inode->i_cdev, struct psee_composite_device, cdev);

	file->private_data = pdev;
	return 0;
}

static int flow_release(struct inode *inode, struct file *file)
{
	return 0;
}

static ssize_t flow_read(struct file *file, char __user *ubuf,
			 size_t count, loff_t *ppos)
{
	struct psee_composite_device *pdev = file->private_data;
	struct flow_buf *buf;
	unsigned long flags;
	size_t to_copy;
	int ret;

	/* Wait for a completed frame */
	if (file->f_flags & O_NONBLOCK) {
		spin_lock_irqsave(&pdev->buf_lock, flags);
		if (list_empty(&pdev->done_list)) {
			spin_unlock_irqrestore(&pdev->buf_lock, flags);
			return -EAGAIN;
		}
		spin_unlock_irqrestore(&pdev->buf_lock, flags);
	} else {
		ret = wait_event_interruptible(pdev->read_wait,
					       !list_empty(&pdev->done_list) ||
					       !pdev->streaming);
		if (ret)
			return ret;

		if (!pdev->streaming && list_empty(&pdev->done_list))
			return 0; /* EOF — streaming stopped */
	}

	/* Dequeue the oldest completed frame */
	spin_lock_irqsave(&pdev->buf_lock, flags);
	if (list_empty(&pdev->done_list)) {
		spin_unlock_irqrestore(&pdev->buf_lock, flags);
		return 0;
	}
	buf = list_first_entry(&pdev->done_list, struct flow_buf, list);
	list_del_init(&buf->list);
	spin_unlock_irqrestore(&pdev->buf_lock, flags);

	/* Copy to userspace */
	to_copy = min(count, buf->bytesused);
	if (copy_to_user(ubuf, buf->vaddr, to_copy)) {
		/* Return buffer to free list even on error */
		spin_lock_irqsave(&pdev->buf_lock, flags);
		list_add_tail(&buf->list, &pdev->free_list);
		spin_unlock_irqrestore(&pdev->buf_lock, flags);
		if (!pdev->active && pdev->streaming)
			schedule_work(&pdev->resubmit_work);
		return -EFAULT;
	}

	/* Return buffer to free list and kick DMA if idle */
	spin_lock_irqsave(&pdev->buf_lock, flags);
	list_add_tail(&buf->list, &pdev->free_list);
	spin_unlock_irqrestore(&pdev->buf_lock, flags);

	if (!pdev->active && pdev->streaming)
		schedule_work(&pdev->resubmit_work);

	return to_copy;
}

static __poll_t flow_poll(struct file *file, struct poll_table_struct *wait)
{
	struct psee_composite_device *pdev = file->private_data;
	__poll_t mask = 0;
	unsigned long flags;

	poll_wait(file, &pdev->read_wait, wait);

	spin_lock_irqsave(&pdev->buf_lock, flags);
	if (!list_empty(&pdev->done_list))
		mask |= EPOLLIN | EPOLLRDNORM;
	spin_unlock_irqrestore(&pdev->buf_lock, flags);

	if (!pdev->streaming)
		mask |= EPOLLHUP;

	return mask;
}

static const struct file_operations flow_fops = {
	.owner   = THIS_MODULE,
	.open    = flow_open,
	.release = flow_release,
	.read    = flow_read,
	.poll    = flow_poll,
};

static int flow_chrdev_init(struct psee_composite_device *pdev)
{
	int ret;

	ret = alloc_chrdev_region(&pdev->devno, 0, 1, FLOW_DEV_NAME);
	if (ret < 0) {
		dev_err(pdev->dev, "alloc_chrdev_region: %d\n", ret);
		return ret;
	}

	cdev_init(&pdev->cdev, &flow_fops);
	pdev->cdev.owner = THIS_MODULE;

	ret = cdev_add(&pdev->cdev, pdev->devno, 1);
	if (ret < 0) {
		dev_err(pdev->dev, "cdev_add: %d\n", ret);
		goto err_region;
	}

	pdev->cls = class_create(THIS_MODULE, FLOW_DEV_NAME);
	if (IS_ERR(pdev->cls)) {
		ret = PTR_ERR(pdev->cls);
		dev_err(pdev->dev, "class_create: %d\n", ret);
		goto err_cdev;
	}

	pdev->chrdev = device_create(pdev->cls, pdev->dev,
				     pdev->devno, pdev, FLOW_DEV_NAME);
	if (IS_ERR(pdev->chrdev)) {
		ret = PTR_ERR(pdev->chrdev);
		dev_err(pdev->dev, "device_create: %d\n", ret);
		goto err_class;
	}

	dev_info(pdev->dev, "created /dev/%s\n", FLOW_DEV_NAME);
	return 0;

err_class:
	class_destroy(pdev->cls);
err_cdev:
	cdev_del(&pdev->cdev);
err_region:
	unregister_chrdev_region(pdev->devno, 1);
	return ret;
}

static void flow_chrdev_cleanup(struct psee_composite_device *pdev)
{
	device_destroy(pdev->cls, pdev->devno);
	class_destroy(pdev->cls);
	cdev_del(&pdev->cdev);
	unregister_chrdev_region(pdev->devno, 1);
}

/* ------------------------------------------------------------------ */
/*  Graph Management (unchanged from psee-video)                      */
/* ------------------------------------------------------------------ */

static struct psee_graph_entity *
psee_graph_find_entity(struct psee_composite_device *pdev,
		       const struct fwnode_handle *fwnode)
{
	struct psee_graph_entity *entity;
	struct v4l2_async_subdev *asd;

	list_for_each_entry(asd, &pdev->notifier.asd_list, asd_list) {
		entity = to_psee_entity(asd);
		if (entity->asd.match.fwnode == fwnode)
			return entity;
	}

	return NULL;
}

static int psee_graph_build_one(struct psee_composite_device *pdev,
				struct psee_graph_entity *entity)
{
	u32 link_flags = MEDIA_LNK_FL_ENABLED;
	struct media_entity *local = entity->entity;
	struct media_entity *remote;
	struct media_pad *local_pad;
	struct media_pad *remote_pad;
	struct psee_graph_entity *ent;
	struct v4l2_fwnode_link link;
	struct fwnode_handle *ep = NULL;
	int ret = 0;

	dev_dbg(pdev->dev, "creating links for entity %s\n", local->name);

	while (1) {
		ep = fwnode_graph_get_next_endpoint(entity->asd.match.fwnode,
						    ep);
		if (ep == NULL)
			break;

		ret = v4l2_fwnode_parse_link(ep, &link);
		if (ret < 0) {
			dev_err(pdev->dev, "failed to parse link for %p\n",
				ep);
			continue;
		}

		if (link.local_port >= local->num_pads) {
			dev_err(pdev->dev, "invalid port number %u for %p\n",
				link.local_port, link.local_node);
			v4l2_fwnode_put_link(&link);
			ret = -EINVAL;
			break;
		}

		local_pad = &local->pads[link.local_port];

		if (local_pad->flags & MEDIA_PAD_FL_SINK) {
			v4l2_fwnode_put_link(&link);
			continue;
		}

		/* Skip our own node (DMA endpoint) */
		if (link.remote_node == of_fwnode_handle(pdev->dev->of_node)) {
			v4l2_fwnode_put_link(&link);
			continue;
		}

		ent = psee_graph_find_entity(pdev, link.remote_node);
		if (ent == NULL) {
			dev_err(pdev->dev, "no entity found for %p\n",
				link.remote_node);
			v4l2_fwnode_put_link(&link);
			ret = -ENODEV;
			break;
		}

		remote = ent->entity;

		if (link.remote_port >= remote->num_pads) {
			dev_err(pdev->dev, "invalid port number %u on %p\n",
				link.remote_port, link.remote_node);
			v4l2_fwnode_put_link(&link);
			ret = -EINVAL;
			break;
		}

		remote_pad = &remote->pads[link.remote_port];
		v4l2_fwnode_put_link(&link);

		dev_dbg(pdev->dev, "creating %s:%u -> %s:%u link\n",
			local->name, local_pad->index,
			remote->name, remote_pad->index);

		ret = media_create_pad_link(local, local_pad->index,
					    remote, remote_pad->index,
					    link_flags);
		if (ret < 0) {
			dev_err(pdev->dev,
				"failed to create %s:%u -> %s:%u link\n",
				local->name, local_pad->index,
				remote->name, remote_pad->index);
			break;
		}
	}

	fwnode_handle_put(ep);
	return ret;
}

static int psee_graph_notify_complete(struct v4l2_async_notifier *notifier)
{
	struct psee_composite_device *pdev =
		container_of(notifier, struct psee_composite_device, notifier);
	struct psee_graph_entity *entity;
	struct v4l2_async_subdev *asd;
	int ret;

	list_for_each_entry(asd, &pdev->notifier.asd_list, asd_list) {
		entity = to_psee_entity(asd);
		ret = psee_graph_build_one(pdev, entity);
		if (ret < 0)
			return ret;
	}

	ret = v4l2_device_register_subdev_nodes(&pdev->v4l2_dev);
	if (ret < 0)
		dev_err(pdev->dev, "failed to register subdev nodes\n");

	dev_info(pdev->dev, "pipeline complete, subdev nodes registered\n");

	return media_device_register(&pdev->media_dev);
}

static int psee_graph_notify_bound(struct v4l2_async_notifier *notifier,
				   struct v4l2_subdev *subdev,
				   struct v4l2_async_subdev *unused)
{
	struct psee_composite_device *pdev =
		container_of(notifier, struct psee_composite_device, notifier);
	struct psee_graph_entity *entity;
	struct v4l2_async_subdev *asd;

	list_for_each_entry(asd, &pdev->notifier.asd_list, asd_list) {
		entity = to_psee_entity(asd);

		if (entity->asd.match.fwnode != subdev->fwnode)
			continue;

		if (entity->subdev) {
			dev_err(pdev->dev, "duplicate subdev for node %p\n",
				entity->asd.match.fwnode);
			return -EINVAL;
		}

		dev_info(pdev->dev, "bound subdev: %s\n", subdev->name);
		entity->entity = &subdev->entity;
		entity->subdev = subdev;
		return 0;
	}

	dev_err(pdev->dev, "no entity for subdev %s\n", subdev->name);
	return -EINVAL;
}

static const struct v4l2_async_notifier_operations psee_graph_notify_ops = {
	.bound = psee_graph_notify_bound,
	.complete = psee_graph_notify_complete,
};

static int psee_graph_parse_one(struct psee_composite_device *pdev,
				struct fwnode_handle *fwnode)
{
	struct fwnode_handle *remote;
	struct fwnode_handle *ep = NULL;
	int ret = 0;

	while (1) {
		struct psee_graph_entity *xge;

		ep = fwnode_graph_get_next_endpoint(fwnode, ep);
		if (ep == NULL)
			break;

		remote = fwnode_graph_get_remote_port_parent(ep);
		if (remote == NULL) {
			ret = -EINVAL;
			goto err_notifier_cleanup;
		}

		fwnode_handle_put(ep);

		if (remote == of_fwnode_handle(pdev->dev->of_node) ||
		    psee_graph_find_entity(pdev, remote)) {
			fwnode_handle_put(remote);
			continue;
		}

		xge = v4l2_async_notifier_add_fwnode_subdev(
			&pdev->notifier, remote,
			struct psee_graph_entity);
		fwnode_handle_put(remote);
		if (IS_ERR(xge)) {
			ret = PTR_ERR(xge);
			goto err_notifier_cleanup;
		}
	}

	return 0;

err_notifier_cleanup:
	v4l2_async_notifier_cleanup(&pdev->notifier);
	fwnode_handle_put(ep);
	return ret;
}

static int psee_graph_parse(struct psee_composite_device *pdev)
{
	struct psee_graph_entity *entity;
	struct v4l2_async_subdev *asd;
	int ret;

	ret = psee_graph_parse_one(pdev, of_fwnode_handle(pdev->dev->of_node));
	if (ret < 0)
		return 0;

	list_for_each_entry(asd, &pdev->notifier.asd_list, asd_list) {
		entity = to_psee_entity(asd);
		ret = psee_graph_parse_one(pdev, entity->asd.match.fwnode);
		if (ret < 0) {
			v4l2_async_notifier_cleanup(&pdev->notifier);
			break;
		}
	}

	return ret;
}

static void psee_graph_cleanup(struct psee_composite_device *pdev)
{
	v4l2_async_notifier_unregister(&pdev->notifier);
	v4l2_async_notifier_cleanup(&pdev->notifier);
}

static int psee_graph_init(struct psee_composite_device *pdev)
{
	int ret;

	ret = psee_graph_parse(pdev);
	if (ret < 0) {
		dev_err(pdev->dev, "graph parsing failed\n");
		goto done;
	}

	if (list_empty(&pdev->notifier.asd_list)) {
		dev_err(pdev->dev, "no subdev found in graph\n");
		ret = -ENOENT;
		goto done;
	}

	pdev->notifier.ops = &psee_graph_notify_ops;

	ret = v4l2_async_notifier_register(&pdev->v4l2_dev, &pdev->notifier);
	if (ret < 0) {
		dev_err(pdev->dev, "notifier registration failed\n");
		goto done;
	}

	ret = 0;

done:
	if (ret < 0)
		psee_graph_cleanup(pdev);

	return ret;
}

/* ------------------------------------------------------------------ */
/*  Sysfs streaming control (pipeline + DMA)                          */
/* ------------------------------------------------------------------ */

static ssize_t stream_show(struct device *dev,
			   struct device_attribute *attr, char *buf)
{
	struct psee_composite_device *pdev = dev_get_drvdata(dev);

	return sysfs_emit(buf, "%d\n", pdev->streaming);
}

static ssize_t stream_store(struct device *dev,
			    struct device_attribute *attr,
			    const char *buf, size_t count)
{
	struct psee_composite_device *pdev = dev_get_drvdata(dev);
	struct psee_graph_entity *entity;
	struct v4l2_async_subdev *asd;
	int enable, ret;
	int started = 0;

	ret = kstrtoint(buf, 0, &enable);
	if (ret)
		return ret;

	enable = !!enable;
	if (enable == pdev->streaming)
		return count;

	if (enable) {
		/* Start DMA first so it's ready to receive data */
		ret = flow_dma_start(pdev);
		if (ret) {
			dev_err(dev, "DMA start failed: %d\n", ret);
			return ret;
		}

		/* First pass: non-sensor subdevs */
		list_for_each_entry(asd, &pdev->notifier.asd_list, asd_list) {
			entity = to_psee_entity(asd);
			if (!entity->subdev)
				continue;
			if (entity->entity->function ==
			    MEDIA_ENT_F_CAM_SENSOR)
				continue;

			dev_info(dev, "s_stream(1) -> %s\n",
				 entity->subdev->name);
			ret = v4l2_subdev_call(entity->subdev,
					      video, s_stream, 1);
			if (ret && ret != -ENOIOCTLCMD) {
				dev_err(dev, "  failed: %d\n", ret);
				flow_dma_stop(pdev);
				goto err_stop;
			}
			entity->streaming = true;
			started++;
		}

		/* Second pass: sensors (start last) */
		list_for_each_entry(asd, &pdev->notifier.asd_list, asd_list) {
			entity = to_psee_entity(asd);
			if (!entity->subdev)
				continue;
			if (entity->entity->function !=
			    MEDIA_ENT_F_CAM_SENSOR)
				continue;

			dev_info(dev, "s_stream(1) -> %s (sensor)\n",
				 entity->subdev->name);
			ret = v4l2_subdev_call(entity->subdev,
					      video, s_stream, 1);
			if (ret && ret != -ENOIOCTLCMD) {
				dev_err(dev, "  failed: %d\n", ret);
				flow_dma_stop(pdev);
				goto err_stop;
			}
			entity->streaming = true;
			started++;
		}

		dev_info(dev, "streaming ON (%d subdevs + DMA)\n", started);
	} else {
		/* Stop DMA first */
		flow_dma_stop(pdev);

		/* Stop sensors first */
		list_for_each_entry(asd, &pdev->notifier.asd_list, asd_list) {
			entity = to_psee_entity(asd);
			if (!entity->subdev || !entity->streaming)
				continue;
			if (entity->entity->function !=
			    MEDIA_ENT_F_CAM_SENSOR)
				continue;

			dev_info(dev, "s_stream(0) -> %s (sensor)\n",
				 entity->subdev->name);
			v4l2_subdev_call(entity->subdev,
					 video, s_stream, 0);
			entity->streaming = false;
		}

		/* Stop everything else */
		list_for_each_entry(asd, &pdev->notifier.asd_list, asd_list) {
			entity = to_psee_entity(asd);
			if (!entity->subdev || !entity->streaming)
				continue;

			dev_info(dev, "s_stream(0) -> %s\n",
				 entity->subdev->name);
			v4l2_subdev_call(entity->subdev,
					 video, s_stream, 0);
			entity->streaming = false;
		}

		/* Wake any blocked readers */
		wake_up_interruptible(&pdev->read_wait);

		dev_info(dev, "streaming OFF\n");
	}

	pdev->streaming = enable;
	return count;

err_stop:
	list_for_each_entry(asd, &pdev->notifier.asd_list, asd_list) {
		entity = to_psee_entity(asd);
		if (!entity->subdev || !entity->streaming)
			continue;
		v4l2_subdev_call(entity->subdev, video, s_stream, 0);
		entity->streaming = false;
	}
	return ret;
}

static DEVICE_ATTR_RW(stream);

static ssize_t subdevs_show(struct device *dev,
			    struct device_attribute *attr, char *buf)
{
	struct psee_composite_device *pdev = dev_get_drvdata(dev);
	struct psee_graph_entity *entity;
	struct v4l2_async_subdev *asd;
	int len = 0, i = 0;

	list_for_each_entry(asd, &pdev->notifier.asd_list, asd_list) {
		entity = to_psee_entity(asd);
		if (entity->subdev)
			len += sysfs_emit_at(buf, len, "[%d] %s%s\n",
					     i++, entity->subdev->name,
					     entity->streaming ?
					     " (streaming)" : "");
	}

	if (i == 0)
		len = sysfs_emit(buf, "(no subdevs bound)\n");

	return len;
}

static DEVICE_ATTR_RO(subdevs);

static ssize_t dma_stats_show(struct device *dev,
			      struct device_attribute *attr, char *buf)
{
	struct psee_composite_device *pdev = dev_get_drvdata(dev);
	unsigned long flags;
	int n_free = 0, n_done = 0;
	struct flow_buf *b;

	spin_lock_irqsave(&pdev->buf_lock, flags);
	list_for_each_entry(b, &pdev->free_list, list)
		n_free++;
	list_for_each_entry(b, &pdev->done_list, list)
		n_done++;
	spin_unlock_irqrestore(&pdev->buf_lock, flags);

	return sysfs_emit(buf,
			  "free: %d\ndone: %d\nactive: %d\n"
			  "streaming: %d\nframes_done: %lu\n",
			  n_free, n_done, pdev->active ? 1 : 0,
			  pdev->streaming, pdev->frames_done);
}

static DEVICE_ATTR_RO(dma_stats);

static struct attribute *snn_flow_driver_attrs[] = {
	&dev_attr_stream.attr,
	&dev_attr_subdevs.attr,
	&dev_attr_dma_stats.attr,
	NULL,
};

ATTRIBUTE_GROUPS(snn_flow_driver);

/* ------------------------------------------------------------------ */
/*  Media Controller and V4L2                                         */
/* ------------------------------------------------------------------ */

static void psee_composite_v4l2_cleanup(struct psee_composite_device *pdev)
{
	v4l2_device_unregister(&pdev->v4l2_dev);
	media_device_unregister(&pdev->media_dev);
	media_device_cleanup(&pdev->media_dev);
}

static int psee_composite_v4l2_init(struct psee_composite_device *pdev)
{
	int ret;

	pdev->media_dev.dev = pdev->dev;
	strscpy(pdev->media_dev.model, "Event Camera Pipeline",
		sizeof(pdev->media_dev.model));
	pdev->media_dev.hw_revision = 0;

	media_device_init(&pdev->media_dev);

	pdev->v4l2_dev.mdev = &pdev->media_dev;
	ret = v4l2_device_register(pdev->dev, &pdev->v4l2_dev);
	if (ret < 0) {
		dev_err(pdev->dev, "V4L2 device registration failed (%d)\n",
			ret);
		media_device_cleanup(&pdev->media_dev);
		return ret;
	}

	return 0;
}

/* ------------------------------------------------------------------ */
/*  Platform Device Driver                                            */
/* ------------------------------------------------------------------ */

static int psee_composite_probe(struct platform_device *platform_dev)
{
	struct psee_composite_device *pdev;
	int ret;

	pdev = devm_kzalloc(&platform_dev->dev, sizeof(*pdev), GFP_KERNEL);
	if (!pdev)
		return -ENOMEM;

	pdev->dev = &platform_dev->dev;
	pdev->platform_dev = platform_dev;
	INIT_LIST_HEAD(&pdev->dmas);
	v4l2_async_notifier_init(&pdev->notifier);
	spin_lock_init(&pdev->buf_lock);
	init_waitqueue_head(&pdev->read_wait);
	INIT_WORK(&pdev->resubmit_work, flow_resubmit_work_fn);

	/* DMA mask for 33-bit addressing (xlnx,addrwidth = 0x21) */
	ret = dma_set_mask_and_coherent(&platform_dev->dev, DMA_BIT_MASK(33));
	if (ret) {
		dev_err(&platform_dev->dev, "dma_set_mask: %d\n", ret);
		return ret;
	}

	/* V4L2 / media controller */
	ret = psee_composite_v4l2_init(pdev);
	if (ret < 0)
		return ret;

	/* Pipeline graph */
	ret = psee_graph_init(pdev);
	if (ret < 0)
		goto err_v4l2;

	/* Reserved memory */
	ret = of_reserved_mem_device_init(&platform_dev->dev);
	if (ret)
		dev_dbg(&platform_dev->dev,
			"of_reserved_mem_device_init: %d\n", ret);

	/* Request DMA channel */
	pdev->dma_chan = dma_request_chan(&platform_dev->dev, "rx");
	if (IS_ERR(pdev->dma_chan)) {
		ret = PTR_ERR(pdev->dma_chan);
		if (ret == -EPROBE_DEFER)
			goto err_graph;
		dev_err(&platform_dev->dev, "dma_request_chan: %d\n", ret);
		goto err_graph;
	}

	/* Allocate DMA buffers */
	ret = flow_alloc_buffers(pdev);
	if (ret)
		goto err_dma_chan;

	/* Char device */
	ret = flow_chrdev_init(pdev);
	if (ret)
		goto err_bufs;

	platform_set_drvdata(platform_dev, pdev);

	dev_info(pdev->dev, "device registered (DMA + /dev/%s)\n",
		 FLOW_DEV_NAME);

	return 0;

err_bufs:
	flow_free_buffers(pdev);
err_dma_chan:
	dma_release_channel(pdev->dma_chan);
err_graph:
	psee_graph_cleanup(pdev);
err_v4l2:
	psee_composite_v4l2_cleanup(pdev);
	return ret;
}

static int psee_composite_remove(struct platform_device *platform_dev)
{
	struct psee_composite_device *pdev = platform_get_drvdata(platform_dev);

	/* Stop streaming if active */
	if (pdev->streaming) {
		struct psee_graph_entity *entity;
		struct v4l2_async_subdev *asd;

		flow_dma_stop(pdev);

		list_for_each_entry(asd, &pdev->notifier.asd_list, asd_list) {
			entity = to_psee_entity(asd);
			if (entity->subdev && entity->streaming) {
				v4l2_subdev_call(entity->subdev,
						 video, s_stream, 0);
				entity->streaming = false;
			}
		}
	}

	flow_chrdev_cleanup(pdev);
	flow_free_buffers(pdev);
	dma_release_channel(pdev->dma_chan);
	psee_graph_cleanup(pdev);
	psee_composite_v4l2_cleanup(pdev);

	return 0;
}

static const struct of_device_id psee_composite_of_id_table[] = {
	{ .compatible = "custom,snn-flow-driver" },
	{ }
};
MODULE_DEVICE_TABLE(of, psee_composite_of_id_table);

static struct platform_driver psee_composite_driver = {
	.driver = {
		.name = DRIVER_NAME,
		.of_match_table = psee_composite_of_id_table,
		.dev_groups = snn_flow_driver_groups,
	},
	.probe = psee_composite_probe,
	.remove = psee_composite_remove,
};

module_platform_driver(psee_composite_driver);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Event camera pipeline + DMA driver for KV260");
