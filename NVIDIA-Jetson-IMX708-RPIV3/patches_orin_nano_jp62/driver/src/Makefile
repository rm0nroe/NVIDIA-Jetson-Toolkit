# Makefile for IMX708 sensor driver - Out of tree build
# JetPack 6.2 (L4T R36.4.x)

obj-m := nv_imx708.o

# Include paths for tegracam headers
ccflags-y := -I$(KERNEL_SRC)/nvidia-oot/include
ccflags-y += -I$(KERNEL_SRC)/nvidia/include
ccflags-y += -I$(src)/../include
