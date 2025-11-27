# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains kernel driver patches for the Sony IMX708 camera sensor (Raspberry Pi Camera Module 3) for NVIDIA Jetson platforms. The patches are applied to NVIDIA JetPack kernel sources to add camera support.

## Repository Structure

- `patches_nano/patches/` - Patches for Jetson Nano (JetPack 4.6.4)
- `patches_orin_nano/patches/` - Patches for Jetson Orin Nano (JetPack 5.1.1 and 6.0)
- `patches_orin_nano_jp62/driver/` - Out-of-tree driver for JetPack 6.2 (L4T R36.4.x)
- `series` files - Used by quilt tool to apply patches (JetPack 6.0 uses git instead)

## JetPack 6.2 Support

JetPack 6.2 uses a different device tree structure than JP6.0, so a standalone out-of-tree build is provided:

```bash
cd patches_orin_nano_jp62/driver
./build.sh           # Build module and DTBO
./build.sh install   # Install to system
# Edit /boot/extlinux/extlinux.conf to add OVERLAYS line
sudo reboot
./validate.sh        # Verify installation
```

## Patch Application (JetPack 4.6.4 - 6.0)

Patches are applied to external JetPack kernel sources:
- JetPack 4.6.4/5.1.1: Use quilt tool with the `series` file
- JetPack 6.0: Use git to apply the patch directly

Full instructions: https://developer.ridgerun.com/wiki/index.php/Raspberry_Pi_Camera_Module_3_IMX708_Linux_driver_for_Jetson

## Supported Configuration

- **Resolution**: 4608x2592 @ 14fps (framerate range: 2-14 fps)
- **Controls**: Gain, Exposure, Framerate, Group Hold

## Verification Commands

After installing the driver on a Jetson device, verify with GStreamer:

```bash
# Display test
SENSOR_ID=0
FRAMERATE=14
gst-launch-1.0 nvarguscamerasrc sensor-id=$SENSOR_ID ! "video/x-raw(memory:NVMM),width=4608,height=2592,framerate=$FRAMERATE/1" ! queue ! nvegltransform ! nveglglessink

# MP4 recording
gst-launch-1.0 -e nvarguscamerasrc sensor-id=$SENSOR_ID ! "video/x-raw(memory:NVMM),width=4608,height=2592,framerate=$FRAMERATE/1" ! nvv4l2h264enc ! h264parse ! mp4mux ! filesink location=test.mp4
```

## Patch Naming Convention

`<jetpack_version>_<platform>_imx708_v<driver_version>.patch`

Example: `5.1.1_nano_imx708_v0.1.0.patch` is for JetPack 5.1.1 on Orin Nano
