/*
 * flow_display — Display event frames on DisplayPort via DRM/KMS
 *
 * Reads frames from /dev/flow0, marks each (x,y) as a white pixel
 * on a black 320x320 grid, nearest-neighbor upscales to 1080p,
 * and flips to the DisplayPort output.
 *
 * Build:
 *     make flow_display
 *
 * Usage:
 *     ./flow_display              # Run until Ctrl+C
 *     ./flow_display -n 100       # Display 100 frames
 *     ./flow_display -d /dev/dri/card1   # Alternate DRM device
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <getopt.h>
#include <time.h>
#include <sys/ioctl.h>
#include <sys/mman.h>

#include <xf86drm.h>
#include <xf86drmMode.h>

/* ------------------------------------------------------------------ */
/*  Constants                                                         */
/* ------------------------------------------------------------------ */

#define FLOW_DEV		"/dev/flow0"
#define DRM_DEV			"/dev/dri/card0"
#define MAX_FRAME_SIZE		(1024 * 1024)
#define BYTES_PER_VEC		8

#define SRC_W			320
#define SRC_H			320
#define BPP			3	/* RGB, 24-bit */

/* Scale factor: 3x gives 960x960, centered in 1920x1080 */
#define SCALE			3
#define SCALED_W		(SRC_W * SCALE)	 /* 960 */
#define SCALED_H		(SRC_H * SCALE)	 /* 960 */

/* ------------------------------------------------------------------ */
/*  DRM buffer                                                        */
/* ------------------------------------------------------------------ */

typedef struct {
	uint32_t handle;
	uint32_t fb_id;
	uint32_t stride;
	uint32_t size;
	uint8_t *map;
} drm_buf_t;

typedef struct {
	int		 fd;
	uint32_t	 conn_id;
	uint32_t	 crtc_id;
	drmModeModeInfo	 mode;
	drm_buf_t	 bufs[2];
	int		 front;
} flow_drm_ctx_t;

/* ------------------------------------------------------------------ */
/*  Signal handling                                                   */
/* ------------------------------------------------------------------ */

static volatile int g_quit = 0;

static void on_signal(int sig)
{
	(void)sig;
	g_quit = 1;
}

/* ------------------------------------------------------------------ */
/*  Sign extension                                                    */
/* ------------------------------------------------------------------ */

static inline int sign_extend_9(unsigned int val)
{
	if (val & 0x100)
		return (int)(val | 0xFFFFFE00);
	return (int)val;
}

/* ------------------------------------------------------------------ */
/*  DRM setup (from dp_test)                                          */
/* ------------------------------------------------------------------ */

static int find_display(flow_drm_ctx_t *ctx, uint32_t req_w, uint32_t req_h)
{
	drmModeRes *res = drmModeGetResources(ctx->fd);
	if (!res) {
		fprintf(stderr, "drmModeGetResources: %s\n", strerror(errno));
		return -1;
	}

	for (int i = 0; i < res->count_connectors; i++) {
		drmModeConnector *conn =
			drmModeGetConnector(ctx->fd, res->connectors[i]);
		if (!conn) continue;
		if (conn->connection != DRM_MODE_CONNECTED ||
		    conn->count_modes == 0) {
			drmModeFreeConnector(conn);
			continue;
		}

		drmModeModeInfo *best = NULL;
		for (int m = 0; m < conn->count_modes; m++) {
			if (conn->modes[m].hdisplay == req_w &&
			    conn->modes[m].vdisplay == req_h) {
				best = &conn->modes[m];
				break;
			}
		}
		if (!best) {
			for (int m = 0; m < conn->count_modes; m++) {
				if (conn->modes[m].type & DRM_MODE_TYPE_PREFERRED) {
					best = &conn->modes[m];
					break;
				}
			}
		}
		if (!best) best = &conn->modes[0];

		drmModeEncoder *enc = NULL;
		if (conn->encoder_id)
			enc = drmModeGetEncoder(ctx->fd, conn->encoder_id);
		if (!enc) {
			for (int e = 0; e < conn->count_encoders; e++) {
				enc = drmModeGetEncoder(ctx->fd, conn->encoders[e]);
				if (enc) break;
			}
		}
		if (!enc) { drmModeFreeConnector(conn); continue; }

		uint32_t crtc_id = enc->crtc_id;
		if (!crtc_id) {
			for (int c = 0; c < res->count_crtcs; c++) {
				if (enc->possible_crtcs & (1 << c)) {
					crtc_id = res->crtcs[c];
					break;
				}
			}
		}
		drmModeFreeEncoder(enc);
		if (!crtc_id) { drmModeFreeConnector(conn); continue; }

		ctx->conn_id = conn->connector_id;
		ctx->crtc_id = crtc_id;
		ctx->mode    = *best;

		fprintf(stderr, "Display: connector %u, CRTC %u, %ux%u@%u\n",
			ctx->conn_id, ctx->crtc_id,
			best->hdisplay, best->vdisplay, best->vrefresh);

		drmModeFreeConnector(conn);
		drmModeFreeResources(res);
		return 0;
	}

	drmModeFreeResources(res);
	fprintf(stderr, "No connected display found.\n");
	return -1;
}

static int create_dumb_fb(int fd, uint32_t w, uint32_t h, drm_buf_t *buf)
{
	struct drm_mode_create_dumb creq = {
		.width = w, .height = h, .bpp = 24,
	};
	if (drmIoctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &creq) < 0) {
		fprintf(stderr, "CREATE_DUMB: %s\n", strerror(errno));
		return -1;
	}
	buf->handle = creq.handle;
	buf->stride = creq.pitch;
	buf->size   = creq.size;

	uint32_t handles[4] = { buf->handle };
	uint32_t strides[4] = { buf->stride };
	uint32_t offsets[4] = { 0 };
	uint32_t fmt = 'R' | ('G' << 8) | ('2' << 16) | ('4' << 24);

	if (drmModeAddFB2(fd, w, h, fmt,
			  handles, strides, offsets, &buf->fb_id, 0) < 0) {
		fprintf(stderr, "AddFB2: %s\n", strerror(errno));
		return -1;
	}

	struct drm_mode_map_dumb mreq = { .handle = buf->handle };
	if (drmIoctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &mreq) < 0) {
		fprintf(stderr, "MAP_DUMB: %s\n", strerror(errno));
		return -1;
	}

	buf->map = mmap(NULL, buf->size,
			PROT_READ | PROT_WRITE, MAP_SHARED,
			fd, mreq.offset);
	if (buf->map == MAP_FAILED) {
		fprintf(stderr, "mmap: %s\n", strerror(errno));
		return -1;
	}
	memset(buf->map, 0, buf->size);
	return 0;
}

static void destroy_dumb_fb(int fd, drm_buf_t *buf)
{
	if (buf->map && buf->map != MAP_FAILED)
		munmap(buf->map, buf->size);
	if (buf->fb_id)
		drmModeRmFB(fd, buf->fb_id);
	if (buf->handle) {
		struct drm_mode_destroy_dumb d = { .handle = buf->handle };
		drmIoctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &d);
	}
	memset(buf, 0, sizeof(*buf));
}

/* ------------------------------------------------------------------ */
/*  Render: events -> RGB framebuffer                                 */
/* ------------------------------------------------------------------ */

static void render_frame(const uint8_t *dma_buf, size_t dma_len,
			 drm_buf_t *fb, uint32_t disp_w, uint32_t disp_h)
{
	/* Clear framebuffer to black */
	memset(fb->map, 0, fb->size);

	/* Source grid: 320x320, one byte per pixel (on/off) */
	uint8_t grid[SRC_W * SRC_H];
	memset(grid, 0, sizeof(grid));

	/* Parse DMA vectors and mark pixels */
	int n_vectors = dma_len / BYTES_PER_VEC;
	for (int i = 0; i < n_vectors; i++) {
		uint64_t word;
		memcpy(&word, dma_buf + i * BYTES_PER_VEC, sizeof(word));

		unsigned int fh_x = (word >> 27) & 0x1FF;
		unsigned int fh_y = (word >> 18) & 0x1FF;

		if (fh_x < SRC_W && fh_y < SRC_H)
			grid[fh_y * SRC_W + fh_x] = 255;
	}

	/* Nearest-neighbor upscale, centered in display */
	uint32_t off_x = (disp_w - SCALED_W) / 2;
	uint32_t off_y = (disp_h - SCALED_H) / 2;

	for (uint32_t sy = 0; sy < SRC_H; sy++) {
		for (uint32_t sx = 0; sx < SRC_W; sx++) {
			uint8_t val = grid[sy * SRC_W + sx];
			if (!val)
				continue;

			/* Fill the scaled block */
			for (int dy = 0; dy < SCALE; dy++) {
				uint32_t oy = off_y + sy * SCALE + dy;
				if (oy >= disp_h) continue;
				uint8_t *row = fb->map + oy * fb->stride;

				for (int dx = 0; dx < SCALE; dx++) {
					uint32_t ox = off_x + sx * SCALE + dx;
					if (ox >= disp_w) continue;

					uint8_t *p = row + ox * BPP;
					p[0] = val; /* R */
					p[1] = val; /* G */
					p[2] = val; /* B */
				}
			}
		}
	}
}

/* ------------------------------------------------------------------ */
/*  Timing                                                            */
/* ------------------------------------------------------------------ */

static uint64_t now_us(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (uint64_t)ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
}

/* ------------------------------------------------------------------ */
/*  Main                                                              */
/* ------------------------------------------------------------------ */

int main(int argc, char *argv[])
{
	int max_frames = -1;
	const char *drm_dev = DRM_DEV;
	const char *flow_dev = FLOW_DEV;
	int opt;

	while ((opt = getopt(argc, argv, "n:d:f:")) != -1) {
		switch (opt) {
		case 'n': max_frames = atoi(optarg); break;
		case 'd': drm_dev = optarg; break;
		case 'f': flow_dev = optarg; break;
		default:
			fprintf(stderr,
				"Usage: %s [-n frames] [-d drm_dev] [-f flow_dev]\n",
				argv[0]);
			return 1;
		}
	}

	/* ---- Signal handling ----------------------------------------- */
	struct sigaction sa;
	memset(&sa, 0, sizeof(sa));
	sa.sa_handler = on_signal;
	sa.sa_flags = 0;
	sigaction(SIGINT, &sa, NULL);
	sigaction(SIGTERM, &sa, NULL);

	/* ---- Open flow device ---------------------------------------- */
	int flow_fd = open(flow_dev, O_RDONLY);
	if (flow_fd < 0) {
		perror("open flow device");
		return 1;
	}

	uint8_t *dma_buf = malloc(MAX_FRAME_SIZE);
	if (!dma_buf) {
		perror("malloc");
		close(flow_fd);
		return 1;
	}

	/* ---- Open DRM device ----------------------------------------- */
	flow_drm_ctx_t drm;
	memset(&drm, 0, sizeof(drm));

	drm.fd = open(drm_dev, O_RDWR | O_CLOEXEC);
	if (drm.fd < 0) {
		fprintf(stderr, "open %s: %s\n", drm_dev, strerror(errno));
		free(dma_buf);
		close(flow_fd);
		return 1;
	}

	if (drmSetMaster(drm.fd) < 0)
		fprintf(stderr, "Warning: not DRM master: %s\n",
			strerror(errno));

	if (find_display(&drm, 1920, 1080) < 0) {
		close(drm.fd);
		free(dma_buf);
		close(flow_fd);
		return 1;
	}

	uint32_t disp_w = drm.mode.hdisplay;
	uint32_t disp_h = drm.mode.vdisplay;

	for (int i = 0; i < 2; i++) {
		if (create_dumb_fb(drm.fd, disp_w, disp_h, &drm.bufs[i]) < 0) {
			close(drm.fd);
			free(dma_buf);
			close(flow_fd);
			return 1;
		}
	}

	/* Initial modeset */
	drmModeCrtc *orig = drmModeGetCrtc(drm.fd, drm.crtc_id);
	if (drmModeSetCrtc(drm.fd, drm.crtc_id,
			   drm.bufs[0].fb_id, 0, 0,
			   &drm.conn_id, 1, &drm.mode) < 0) {
		fprintf(stderr, "SetCrtc: %s\n", strerror(errno));
		if (orig) drmModeFreeCrtc(orig);
		close(drm.fd);
		free(dma_buf);
		close(flow_fd);
		return 1;
	}

	fprintf(stderr, "Display active (%ux%u). Reading from %s...\n",
		disp_w, disp_h, flow_dev);

	/* ---- Main loop ----------------------------------------------- */
	int frame_num = 0;
	uint64_t t_start = now_us();
	uint64_t last_fps_time = t_start;
	int fps_count = 0;

	while (!g_quit) {
		if (max_frames >= 0 && frame_num >= max_frames)
			break;

		ssize_t n = read(flow_fd, dma_buf, MAX_FRAME_SIZE);
		if (n < 0) {
			if (errno == EINTR)
				continue;
			perror("read");
			break;
		}
		if (n == 0) {
			fprintf(stderr, "EOF\n");
			break;
		}

		int n_vectors = n / BYTES_PER_VEC;

		/* Render into back buffer */
		drm_buf_t *buf = &drm.bufs[drm.front];
		render_frame(dma_buf, n, buf, disp_w, disp_h);

		/* Flip */
		drmModeSetCrtc(drm.fd, drm.crtc_id,
			       buf->fb_id, 0, 0,
			       &drm.conn_id, 1, &drm.mode);
		drm.front ^= 1;

		frame_num++;
		fps_count++;

		/* FPS counter every 2 seconds */
		uint64_t now = now_us();
		if (now - last_fps_time >= 2000000) {
			double fps = fps_count * 1e6 / (now - last_fps_time);
			fprintf(stderr, "\rframe %d | %d vectors | %.1f fps  ",
				frame_num, n_vectors, fps);
			fps_count = 0;
			last_fps_time = now;
		}
	}

	/* ---- Cleanup ------------------------------------------------- */
	fprintf(stderr, "\nDone. %d frames displayed.\n", frame_num);

	if (orig) {
		drmModeSetCrtc(drm.fd, orig->crtc_id, orig->buffer_id,
			       orig->x, orig->y,
			       &drm.conn_id, 1, &orig->mode);
		drmModeFreeCrtc(orig);
	}

	for (int i = 0; i < 2; i++)
		destroy_dumb_fb(drm.fd, &drm.bufs[i]);
	drmDropMaster(drm.fd);
	close(drm.fd);
	free(dma_buf);
	close(flow_fd);

	return 0;
}
