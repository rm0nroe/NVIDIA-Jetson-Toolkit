# IMX708 Driver for JetPack 6.2

## IMPORTANT: CAM1 Port Only

**JetPack 6.2 only supports the IMX708 camera on the CAM1 port, NOT CAM0.**

Connect your camera ribbon cable to the **CAM1** connector on the Jetson Orin Nano.

---

## Quick Start

```bash
# 1. Pull latest changes
cd ~/dev/Nvidia-Jetson-Toolkit/NVIDIA-Jetson-IMX708-RPIV3/patches_orin_nano_jp62/driver
git pull

# 2. Clean previous build (important when switching ports)
./build.sh clean

# 3. Build and install (defaults to CAM1)
./build.sh
sudo ./build.sh install

# 4. Configure CSI connector with jetson-io
cd /opt/nvidia/jetson-io/
sudo python3 jetson-io.py
# Select "Camera IMX477-C" (C = CAM1 port)
# Save and reboot
```

---

## Verification (After Reboot)

```bash
# Check I2C - camera should appear at 0x1a
sudo i2cdetect -y -r 9

# Check video device
ls /dev/video*

# Check kernel messages
sudo dmesg | grep -i imx708
```

**Expected I2C output** (bus 9 for CAM1):
```
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:                         -- -- -- -- -- -- -- --
10: -- -- -- -- -- -- -- -- -- -- 1a -- -- -- -- --
...
```

---

## Test Camera

```bash
SENSOR_ID=0
FRAMERATE=14

# Display test
gst-launch-1.0 nvarguscamerasrc sensor-id=$SENSOR_ID ! \
  "video/x-raw(memory:NVMM),width=4608,height=2592,framerate=$FRAMERATE/1" ! \
  queue ! nvegltransform ! nveglglessink

# Record to MP4
gst-launch-1.0 -e nvarguscamerasrc sensor-id=$SENSOR_ID ! \
  "video/x-raw(memory:NVMM),width=4608,height=2592,framerate=$FRAMERATE/1" ! \
  nvv4l2h264enc ! h264parse ! mp4mux ! filesink location=test.mp4
```

---

## Alternative: Arducam Official Installer

Arducam provides an official installer for IMX708 on JetPack 6.2:

```bash
cd ~
wget https://github.com/ArduCAM/MIPI_Camera/releases/download/v0.0.3/install_full.sh
chmod +x install_full.sh
./install_full.sh -m imx708
```

**Note**: Only CAM1 port is supported.

---

## Technical Notes

### Why CAM1 Only?

Per Arducam's compatibility matrix, JetPack 6.2 (L4T 36.4.x) only supports the IMX708 on the CAM1 port. This is a platform limitation.

### Port Mapping

| Port | CSI Interface | I2C Bus | jetson-io Selection |
|------|---------------|---------|---------------------|
| CAM0 | serial_a | Bus 2 | IMX477-A |
| CAM1 | serial_c | Bus 9 (via cam_i2cmux) | IMX477-C |

### GPIO Configuration

The device tree uses GPIO 62 with active-high polarity, matching NVIDIA's jetson-io IMX477-C configuration.

---

## Troubleshooting

### Camera not detected on I2C

1. Verify camera is connected to **CAM1** (not CAM0)
2. Run jetson-io and select **"Camera IMX477-C"**
3. Power cycle the Jetson (full shutdown, not just reboot)
4. Check cable orientation: contacts facing the board

### Check GPIO state

```bash
sudo cat /sys/kernel/debug/gpio | grep -iE "gpio-62|PJ"
```

### Check device tree

```bash
sudo dtc -I fs -O dts /proc/device-tree 2>/dev/null | grep -A10 "imx708\|imx477"
```

### Full diagnostic

```bash
./diagnose_full.sh
```
