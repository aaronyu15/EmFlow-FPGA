#!/bin/bash


# NOTE YOU WILL STILL HAVE TO MANUALLY START THE PIPELINE WITH devmen 0xa0030000 32 1
echo 1 > /sys/devices/platform/axi/a0030000.flow_wrapper/stream
