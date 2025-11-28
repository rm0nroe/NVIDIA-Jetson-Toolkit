# Jetson Orin Nano SSH Setup Guide

## Current Configuration

| Setting | Value |
|---------|-------|
| Hostname | `jetson` |
| Static IP | `192.168.1.231` |
| User | `dev` |
| WiFi Network | `Bear 1` |
| WiFi MAC Address | `58:02:05:DD:F5:CB` |
| Auth | SSH Key (`~/.ssh/id_ed25519`) |

## Quick Connect

```bash
ssh jetson
```

## Headless Operation

1. Power on the Jetson
2. Wait 1-2 minutes for boot + WiFi
3. `ssh jetson` from your Mac

No monitor/keyboard needed.

---

## Switching WiFi Networks

### Step 1: Connect Monitor/Keyboard to Jetson

You need physical access to connect to a new WiFi network.

### Step 2: Connect to New WiFi

```bash
# List available networks
nmcli device wifi list

# Connect to new network (replace "Dark Knight" with network name)
sudo nmcli device wifi connect "Dark Knight" password "your-wifi-password"
```

### Step 3: Get New IP Address

```bash
hostname -I
```

Note the new IP (e.g., `192.168.1.XXX`).

### Step 4: Set Static IP on New Network

```bash
# Set static IP (use the IP from step 3, or choose one)
sudo nmcli con mod "Dark Knight" ipv4.addresses 192.168.1.231/24 ipv4.gateway 192.168.1.1 ipv4.dns "8.8.8.8" ipv4.method manual

# Apply changes
sudo nmcli con up "Dark Knight"

# Verify
hostname -I
```

### Step 5: Update SSH Config on Mac

Edit `~/.ssh/config` on your Mac if IP changed:

```bash
# Only needed if IP changed
nano ~/.ssh/config
```

Update `HostName` to new IP:

```
Host jetson
    HostName 192.168.1.231
    User dev
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

### Step 6: Test Connection

```bash
ssh jetson
```

---

## Troubleshooting

### Cannot Connect (Timeout)

1. **Check Jetson IP:**
   ```bash
   # On Jetson with monitor
   hostname -I
   ```

2. **Update Mac SSH config** with correct IP

3. **Verify Jetson is on same network as Mac:**
   ```bash
   # On Mac
   ping 192.168.1.231
   ```

### IP Keeps Changing

Set static IP (see Step 4 above), or reserve IP in router:

1. Log into router (`192.168.1.1`)
2. Find DHCP Reservation / Static Lease
3. Add: MAC `58:02:05:DD:F5:CB` → IP `192.168.1.231`

### Permission Denied

Re-add SSH key to Jetson:

```bash
# On Jetson
mkdir -p ~/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKEqcSc44INVWiVO+1SN/v56HJ9zFTDrb0zhP4OebMbf macbook" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### SSH Not Running

```bash
# On Jetson
sudo systemctl enable ssh
sudo systemctl start ssh
```

### Network Conflict (Ethernet vs WiFi)

Disable ethernet:

```bash
# On Jetson
sudo nmcli device disconnect enP8p1s0
sudo nmcli con mod "Wired connection 1" connection.autoconnect no
```

---

## Useful Commands

### On Jetson

```bash
# Show all connections
nmcli con show

# Show active connection
nmcli con show --active

# Show connection details
nmcli con show "Bear 1"

# Show device status
nmcli device status

# Show IP addresses
ip addr show

# Restart network connection
sudo nmcli con down "Bear 1" && sudo nmcli con up "Bear 1"

# Check SSH status
sudo systemctl status ssh
```

### On Mac

```bash
# Test connection
ssh -v jetson

# Copy file to Jetson
scp file.txt jetson:~/

# Copy file from Jetson
scp jetson:~/file.txt .

# Run command on Jetson
ssh jetson "command here"
```

---

## Saved WiFi Networks

| Network | Static IP | Gateway |
|---------|-----------|---------|
| Bear 1 | 192.168.1.231/24 | 192.168.1.1 |
| Dark Knight | (configure when needed) | (check router) |

---

## Router IP Reservation (Recommended)

For permanent static IP, add this to your router's DHCP reservation:

| MAC Address | IP Address |
|-------------|------------|
| `58:02:05:DD:F5:CB` | `192.168.1.231` |
