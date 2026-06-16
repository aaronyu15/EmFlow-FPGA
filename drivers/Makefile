obj-m := flow_driver.o
ccflags-y := -I$(PWD)
CC_USER ?= gcc

KDIR ?= /lib/modules/$(shell uname -r)/build

DRM_CFLAGS := $(shell pkg-config --cflags libdrm 2>/dev/null)
DRM_LIBS   := $(shell pkg-config --libs   libdrm 2>/dev/null)

all: modules flow_display flow_color


modules:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

flow_display: flow_display.c
	$(CC_USER) -Wall -O2 $(DRM_CFLAGS) -o $@ $< $(DRM_LIBS) -lm

flow_color: flow_color.c
	$(CC_USER) -Wall -O2 $(DRM_CFLAGS) -o $@ $< $(DRM_LIBS) -lm

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

.PHONY: all clean
