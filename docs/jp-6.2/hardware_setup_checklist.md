# Week 2: Hardware Integration Execution Checklist

**Timeline**: 5 days (Day 0-5)
**Goal**: Complete Jetson Orin Nano Super hardware setup and peripheral integration
**Hardware**: Jetson Orin Nano Super + XVF3800 + IMX708
**Status**: ⚠️ PARTIAL - Audio complete, Vision has platform limitations (December 2025)

---

## ⚠️ Important Notes

### SD Card Image vs SDK Manager

If you flashed via **SD card image**, the `nvidia-jetpack` meta-package is NOT installed. This is normal - all L4T components are present. Verify via:

```bash
cat /etc/nv_tegra_release
# Expected: R36 (release), REVISION: 4.3 (for JP 6.2)
```

### Docker Runtime on Jetson

On Jetson, always use `--runtime=nvidia` instead of `--gpus all`:
```bash
# Wrong (x86 style):
docker run --gpus all ...

# Correct (Jetson):
docker run --runtime=nvidia ...
```

### SSH Configuration for Remote Access

Add to `~/.ssh/config` on your Mac for easy access:
```
Host jetson
    HostName 192.168.1.243
    User jarvi
    IdentityFile ~/.ssh/id_ed25519
```

Then use: `ssh jetson` or `scp jetson:/tmp/file.jpg ~/Desktop/`

---

## 📋 Pre-Execution Checklist

Before starting Day 0, ensure you have:

- [x] **Jetson Orin Nano Super** powered and connected
- [x] **XVF3800 4-Mic Array** with USB-C cable
- [x] **Arducam IMX708 Camera** with 15-pin CSI-2 ribbon cable
- [x] **NVMe SSD** installed in Jetson (for swap and Docker storage)
- [x] **Internet connection** (Ethernet recommended)

---

## Day 0-1: Initial Setup ✅

**Duration**: 4-6 hours
**Goal**: Flash JetPack 6.2 and configure base system

### Step 1: Flash JetPack 6.2

**Option A: MicroSD Card Image (Recommended)**

1. Download: https://developer.nvidia.com/embedded/jetpack-sdk-62
2. Flash with Balena Etcher to 32GB+ microSD
3. Insert into Jetson, connect peripherals, power on
4. Complete Ubuntu setup wizard

**Verify Installation:**
```bash
cat /etc/nv_tegra_release
# Expected: R36 (release), REVISION: 4.3
```

### Step 2: Run Day-0 Setup Script

```bash
cd ~/ai-companion
chmod +x scripts/setup/day0_setup.sh
./scripts/setup/day0_setup.sh
sudo reboot
```

### Day 0-1 Validation Gate ✅

- [x] `nvidia-smi` shows GPU
- [x] `nvpmodel -q` shows MAXN mode
- [x] `swapon --show` shows swap active
- [x] Docker NVIDIA runtime test passes

---

## Day 2-3: Audio Setup ✅

**Duration**: 3-4 hours
**Goal**: Configure XVF3800 with proper channel routing and volume

### Step 1: Connect XVF3800

1. Connect XVF3800 via USB-C to Jetson
2. Verify detection:

```bash
arecord -l | grep -i "xvf3800\|respeaker"
# Expected: card 0: Array [reSpeaker XVF3800 4-Mic Array]
```

### Step 2: Install xvf_host Control Tool

```bash
cd ~/
git clone https://github.com/respeaker/reSpeaker_XVF3800_USB_4MIC_ARRAY.git
cd reSpeaker_XVF3800_USB_4MIC_ARRAY/host_control/jetson
chmod +x xvf_host
sudo ./xvf_host VERSION
```

### Step 3: Configure Audio Channel Routing (CRITICAL!)

> **Warning**: Default AUDIO_MGR_OP_R is (0,0) = SILENCE, causing buzzing instead of voice!

```bash
cd ~/reSpeaker_XVF3800_USB_4MIC_ARRAY/host_control/jetson

# Set Left channel = processed beam (post AEC/beamforming)
sudo ./xvf_host AUDIO_MGR_OP_L 8 0

# Set Right channel = ASR output
sudo ./xvf_host AUDIO_MGR_OP_R 9 0

# Verify
sudo ./xvf_host AUDIO_MGR_OP_L
# Expected: AUDIO_MGR_OP_L MUX_USER_CHOSEN_CHANNELS[8] 0

sudo ./xvf_host AUDIO_MGR_OP_R
# Expected: AUDIO_MGR_OP_R MUX_ALL_USER_CHANNELS[9] 0
```

### Step 4: Configure Volume Levels

```bash
# Set BOTH PCM controls to maximum (CRITICAL for playback!)
amixer -c 0 sset 'PCM',0 60   # USB input level
amixer -c 0 sset 'PCM',1 60   # DAC output (headphone/speaker)

# Set microphone gain for voice (default 10 is too quiet)
sudo ./xvf_host AUDIO_MGR_MIC_GAIN 48

# Save ALSA settings
sudo alsactl store
```

### Step 5: Test Audio

```bash
# Test recording (MUST use stereo -c 2, mono fails!)
arecord -D plughw:0,0 -c 2 -r 16000 -f S16_LE -d 5 /tmp/test.wav

# Test playback
aplay -D plughw:0,0 /tmp/test.wav

# Test tone
speaker-test -D plughw:0,0 -c 2 -t sine -f 440
```

### Day 2-3 Validation Gate ✅

- [x] `arecord -l` shows XVF3800
- [x] Channel routing configured (AUDIO_MGR_OP_L/R)
- [x] PCM volumes set to 60 (both indices)
- [x] Mic gain set to 48
- [x] Recording captures voice clearly (no buzzing)
- [x] Playback works through headphone/speaker

**Documentation**: `docs/jp-6.2/xvf3800_audio_guide.md`

---

## Day 4-5: Vision Setup ⚠️ LIMITED

**Duration**: 2-3 hours
**Goal**: Configure IMX708 camera with RidgeRun driver
**Status**: Camera detected but with **known platform limitations**

> **⚠️ CRITICAL: IMX708 on Jetson has fundamental ISP limitations (December 2025)**
>
> Per Arducam support: *"There is currently no public, robust ISP tuning file for the IMX708 on the Jetson platform. The image quality is a known limitation for this sensor on this hardware."*
>
> **Recommendation**: For production use, consider **IMX477** which has native Jetson ISP support with excellent image quality out of the box.

### Current IMX708 Status on Jetson

| Component | Status | Notes |
|-----------|--------|-------|
| Driver Detection | ✅ Working | `nv_imx708` module loads, sensor detected |
| `/dev/video0` | ✅ Created | V4L2 device exists |
| GStreamer Capture | ⚠️ Partial | Frames capture but with issues |
| Image Quality | ❌ Poor | No ISP tuning file available |
| Mode Mismatch | ⚠️ Issue | Sensor outputs 4608x2592, ISP expects 3840x2160/1920x1080 |

### Technical Root Cause

1. **Native `jetson-io` IMX477 mode** - Produces **BLACK FRAMES** (IMX708 sensor init differs from IMX477)
2. **Mode Parameter Mismatch** - NVIDIA's IMX477-C overlay defines modes for IMX477 (3840x2160, 1920x1080), but IMX708 sensor outputs 4608x2592@14fps
3. **Missing ISP Tuning** - NVIDIA's ISP requires sensor-specific tuning files for proper color processing; IMX708 lacks these
4. **Partial Frames** - When ISP receives 4608x2592 data but expects different resolution, only ~10-20% of frame shows real content

### Step 1: Connect IMX708 Camera

⚠️ **Power off Jetson first!**

1. Locate CSI-2 port (**CAM1 recommended** - I2C Bus 9)
2. Insert ribbon cable (blue side away from board, gold contacts toward board)
3. Close latch firmly
4. Power on

### Step 2: Build and Install RidgeRun IMX708 Driver

The driver source is at `~/imx708-driver` on the Jetson (copied from Mac).

```bash
# Install build dependencies
sudo apt update
sudo apt install -y build-essential device-tree-compiler nvidia-l4t-kernel-headers nvidia-l4t-kernel-oot-headers

# Build and install the driver
cd ~/imx708-driver
make clean && make
sudo make install
```

### Step 3: Create Merged DTB with NVIDIA IMX477 Overlay

The IMX708 driver is modified to also match `ridgerun,imx477` compatible string, allowing it to use NVIDIA's camera infrastructure.

```bash
# Merge NVIDIA IMX477-C overlay with base DTB
sudo fdtoverlay -i /boot/tegra234-p3768-0000+p3767-0005-nv.dtb \
    -o /boot/tegra234-p3768-0000+p3767-0005-imx477-only.dtb \
    /boot/tegra234-p3767-camera-p3768-imx477-C.dtbo
```

### Step 4: Configure Bootloader

Edit `/boot/extlinux/extlinux.conf`:

```
TIMEOUT 30
DEFAULT IMX708

LABEL IMX708
    MENU LABEL IMX708 Camera via NVIDIA IMX477 overlay
    LINUX /boot/Image
    FDT /boot/tegra234-p3768-0000+p3767-0005-imx477-only.dtb
    INITRD /boot/initrd
    APPEND ${cbootargs} root=/dev/mmcblk0p1 rw rootwait rootfstype=ext4 ...
```

Then reboot: `sudo reboot`

### Port Reference

| Camera Port | I2C Bus | Reset GPIO | Notes |
|-------------|---------|------------|-------|
| **CAM0** | Bus 10 | GPIO 62 | Use IMX477-A overlay |
| **CAM1** | Bus 9 | GPIO 160 | Use IMX477-C overlay (recommended) |

### ❌ What Does NOT Work

| Approach | Problem |
|----------|---------|
| Native jetson-io IMX477 mode | **BLACK FRAMES** - IMX708 sensor init differs from IMX477 |
| RidgeRun overlay alone | Missing cam_i2cmux infrastructure |
| Multiple overlays merged | Creates duplicate device nodes (EBUSY -16) |
| Wrong reset GPIO | Camera not detected on I2C |

### ✅ What DOES Work

The working approach uses:
1. **NVIDIA IMX477-C overlay** - Creates camera infrastructure (cam_i2cmux, NVCSI, VI)
2. **RidgeRun nv_imx708 driver** - Modified to match `ridgerun,imx477` compatible string
3. **Merged DTB** - Single fdtoverlay merge, not multiple overlays

### Step 5: Verify Camera Detection

```bash
# Check video device exists
ls -la /dev/video*
# Expected: /dev/video0

# Check driver loaded
lsmod | grep imx
# Expected: nv_imx708

# Check I2C device detection
sudo i2cdetect -y -r 9   # For CAM1
# Look for "UU" at address 0x1a = camera detected

# Check dmesg for success:
sudo dmesg | grep -i imx708
# "imx708 9-001a: detected imx708 sensor"
# "tegra-camrtc-capture-vi tegra-capture-vi: subdev imx708 9-001a bound"
```

### Step 6: Test Camera Capture

```bash
# Capture 1080p test image
gst-launch-1.0 nvarguscamerasrc num-buffers=30 ! \
    'video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1' ! \
    nvjpegenc ! filesink location=/tmp/test.jpg

# Capture 4K test image
gst-launch-1.0 nvarguscamerasrc num-buffers=30 ! \
    'video/x-raw(memory:NVMM),width=3840,height=2160,framerate=30/1' ! \
    nvjpegenc ! filesink location=/tmp/test_4k.jpg

# View on Mac:
scp jetson:/tmp/test.jpg ~/Desktop/ && open ~/Desktop/test.jpg
```

### Available Camera Modes

| Mode | Resolution | FPS | Use Case |
|------|------------|-----|----------|
| Mode 0 | 3840x2160 | 30 | High quality still/video |
| Mode 1 | 1920x1080 | 60 | Real-time video |

### Troubleshooting

**Black frames with jetson-io IMX477 mode:**
- This is expected! Use the RidgeRun driver approach instead.

**"error during i2c read probe (-121)":**
- Wrong reset GPIO configured
- Check cable is seated properly
- Verify camera is on correct port (CAM1 = GPIO 160, CAM0 = GPIO 62)

**No /dev/video0:**
- Check dmesg for binding errors
- Ensure nv_imx708 module is loaded: `lsmod | grep imx`
- Verify DTB is correct: check extlinux.conf FDT line

### Day 4-5 Validation Gate ⚠️

- [x] `/dev/video0` exists
- [x] `nv_imx708` module loaded (NOT nv_imx477)
- [x] I2C address 0x1a detected (shown as "UU" in i2cdetect)
- [x] dmesg shows "detected imx708 sensor"
- [x] GStreamer nvarguscamerasrc runs without crash
- [ ] **BLOCKED**: Full frame capture (partial frames due to mode mismatch)
- [ ] **BLOCKED**: Good image quality (no ISP tuning file available)

### Recommended Alternative: IMX477

For production AI Companion deployment, switch to **IMX477** camera:
- Native Jetson ISP support with professional tuning
- Same 12MP resolution as IMX708
- Proven compatibility with JetPack 6.x
- Available from Arducam, Waveshare, or as Raspberry Pi HQ Camera

**Driver Source**: `~/imx708-driver` on Jetson

---

## Week 2 Complete Status ⚠️

```
Week 2 Progress:
[✓] Day 0-1: JetPack 6.2 flashed and configured
[✓] Day 0-1: System setup (swap, Docker, dependencies)
[✓] Day 2-3: XVF3800 audio with channel routing + mic gain
[⚠] Day 4-5: IMX708 camera detected but with platform limitations
[✓] Day 5:   System health validation

Overall Status: PARTIAL ⚠️
Ready for Week 3: YES (with camera caveats)

Vision Status:
- Camera driver loads and detects sensor
- /dev/video0 created
- GStreamer captures frames (partial)
- BLOCKED: Full frame capture (ISP mode mismatch)
- BLOCKED: Good image quality (no ISP tuning file)
- RECOMMENDATION: Switch to IMX477 for production
```

---

## Quick Test Commands (From Mac)

```bash
# Test camera
ssh jetson 'gst-launch-1.0 nvarguscamerasrc num-buffers=30 ! \
    "video/x-raw(memory:NVMM),width=1920,height=1080,framerate=30/1" ! \
    nvjpegenc ! filesink location=/tmp/test.jpg' && \
    scp jetson:/tmp/test.jpg ~/Desktop/ && open ~/Desktop/test.jpg

# Test audio recording
ssh jetson 'arecord -D plughw:0,0 -c 2 -r 16000 -f S16_LE -d 5 /tmp/test.wav' && \
    scp jetson:/tmp/test.wav ~/Desktop/
```

---

## Next Steps: Week 3 - Service Deployment

| Day | Task | Goal |
|-----|------|------|
| Day 0-1 | Build Docker images | Prepare service containers |
| Day 2 | Deploy Wake + ASR | Voice input pipeline |
| Day 3 | Deploy LLM + TTS | Response generation |
| Day 4 | Deploy Vision (YOLOv8) | Object detection |
| Day 5 | End-to-end test | Full voice pipeline |

**Start Week 3:**
```bash
cd ~/ai-companion
bash scripts/jetson_start.sh
bash scripts/jetson_health.sh
```

---

## Documentation References

| Topic | File |
|-------|------|
| XVF3800 Audio Guide | `docs/jp-6.2/xvf3800_audio_guide.md` |
| IMX708 Camera Guide | `docs/jp-6.2/imx708_driver_install.md` |
| Day 0 Setup Script | `scripts/setup/day0_setup.sh` |
| Audio Setup Script | `scripts/setup/day1_audio_setup.sh` |
| Master Plan | `docs/implementation_master_plan_FINAL_20251109.md` |

---

## JetPack 6.2 Specifications

| Component | Version |
|-----------|---------|
| JetPack | 6.2 |
| L4T | R36.4.3 |
| CUDA | 12.6 |
| TensorRT | 10.3 |
| cuDNN | 9.3 |

**Benefits:**
- Super Mode: Up to 2x generative AI inference performance
- Enhanced Argus library: 40% CPU reduction
- Improved memory bandwidth: 50% boost on Orin Nano

---

**Last Updated**: December 24, 2025
**Tested On**: Jetson Orin Nano Super, JetPack 6.2 (L4T R36.4.3), Kernel 5.15.148-tegra
**Hardware Verified**: XVF3800 (USB audio ✅), IMX708 (partial - ISP limitations ⚠️)
**Camera Method**: RidgeRun nv_imx708 driver + NVIDIA IMX477-C overlay
**Status**: Audio ✅ Production Ready | Vision ⚠️ Limited (switch to IMX477 recommended)

### Lessons Learned (December 2025)

1. **IMX708 has no ISP tuning on Jetson** - Per Arducam: "no public, robust ISP tuning file" exists
2. **Native jetson-io IMX477 mode does NOT work** - Produces black frames with IMX708
3. **RidgeRun driver works but with mode mismatch** - Sensor outputs 4608x2592, ISP expects 3840x2160
4. **IMX477 is recommended** - Native Jetson ISP support with professional tuning
5. **Use nvarguscamerasrc** - Not v4l2src for CSI cameras on Jetson
6. **Keep /boot/dtb/ clean** - Multiple DTBs cause "Multiple DTBs found" errors
7. **GPIO matters** - CAM0 uses GPIO 62, CAM1 uses GPIO 160 for reset

### IMX708 Technical Investigation Summary

| Approach Tried | Result | Root Cause |
|----------------|--------|------------|
| Native jetson-io IMX477-C mode | Black frames | Driver/sensor init mismatch |
| RidgeRun overlay alone | FDT_ERR_NOTFOUND | Missing cam_i2cmux node |
| RidgeRun driver + IMX477-C overlay | Partial frames (~20%) | Mode parameter mismatch |
| Patched mode parameters (4608x2592) | NvBufSurfaceFromFd error | ISP pipeline mismatch |
| Multiple overlays merged | EBUSY -16 | Duplicate device nodes |

**Conclusion**: IMX708 on Jetson requires complete VI/NVCSI/ISP pipeline configuration specific to IMX708 sensor characteristics. This configuration doesn't exist publicly. Use IMX477 for production.
