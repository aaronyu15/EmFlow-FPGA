#!/bin/bash
: ${FORMAT:="PSEE_EVT21"}


# Stop the v4l pipeline otherwise it crashes...
./stop.sh > /dev/null 2&>1

# Force load of tkeep handler driver, so that we don't get the pass-through driver
# probed on tkeep handler
insmod ./flow_driver.ko > /dev/null 2&>1
modprobe psee-tkeep-handler
modprobe psee-event-stream-smart-tracker

# Load the FPGA
xmutil unloadapp
xmutil loadapp snn

# Wait long enough for the drivers to be probed
sleep 1

# Set the pipeline to run in $FORMAT (eg PSEE_EVT3)
media-ctl -V "'genx320 6-003c':0[fmt:$FORMAT/320x320]"
media-ctl -V "'a0010000.mipi_csi2_rx_subsystem':1[fmt:$FORMAT/320x320]"
media-ctl -V "'a0040000.axis_tkeep_handler':1[fmt:$FORMAT/320x320]"
media-ctl -V "'a0050000.event_stream_smart_tra':1[fmt:$FORMAT/320x320]"
# The config of the pipeline can be seen with `media-ctl -p`

bias="${1:-default}"

echo "Bias settings: default, lowlight, min"

# Use low light biases
case "$bias" in
	default)
		echo "Using default biases"
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_diff=51
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_diff_off=28
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_diff_on=25
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_fo=34
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_hpf=40
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_refr=10
		;;
	lowlight)
		echo "Using lowlight biases"
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_diff=51
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_diff_off=19
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_diff_on=24
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_fo=19
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_hpf=0
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_refr=10
		;;
	min)
		echo "Using minimum recommended biases"
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_diff=41
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_diff_off=19
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_diff_on=24
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_fo=19
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_hpf=0
		v4l2-ctl -d /dev/v4l-subdev3 -c bias_refr=0
		;;
esac

	

# Force the sensor to be ON, so that Metavision can do register accesses on it
# Write "auto" to let the sensor be powered down when not streaming
echo on > /sys/class/video4linux/v4l-subdev3/device/power/control

# run with
# MV_LOG_LEVEL=TRACE V4L2_HEAP=reserved  V4L2_SENSOR_PATH=/dev/v4l-subdev3 metavision_viewer

# Enable v4l media pipeline
./start.sh

# Enable SNN control register
devmem 0xa0030000 32 1


echo "SNN pipeline initialized. To enable SNN pipeline do this:"
echo "Display no color ./flow_display or with color ./flow_color"
