# Jetson Orin Nano — Headless SSH Setup

A generic guide for reaching a Jetson Orin Nano over SSH without a monitor or
keyboard. Replace the placeholder values (`<...>`) with your own.

| Setting | Placeholder |
|---------|-------------|
| Hostname / SSH alias | `jetson` |
| Static IP | `192.168.1.100` (example — pick one free on your LAN) |
| User | `<jetson-user>` |
| Auth | SSH key (`~/.ssh/id_ed25519`) |

## Quick Connect

Once configured (see below):

```bash
ssh jetson
```

## Headless Operation

1. Power on the Jetson.
2. Wait 1–2 minutes for boot + network.
3. `ssh jetson` from your computer.

No monitor/keyboard needed after the initial network setup.

---

## First-Time / Switching WiFi Networks

Connecting to a *new* WiFi network requires physical access once (monitor +
keyboard), because the Jetson needs credentials for a network it can't yet reach.

### Step 1: Connect a Monitor/Keyboard to the Jetson

### Step 2: Connect to WiFi

```bash
# List available networks
nmcli device wifi list

# Connect (replace with your SSID and password)
sudo nmcli device wifi connect "<YOUR_WIFI_SSID>" password "<YOUR_WIFI_PASSWORD>"
```

### Step 3: Get the Assigned IP

```bash
hostname -I
```

### Step 4: (Optional) Set a Static IP

A static IP keeps the SSH alias working across reboots.

```bash
# Use the connection name from `nmcli con show`
sudo nmcli con mod "<YOUR_WIFI_SSID>" \
    ipv4.addresses 192.168.1.100/24 \
    ipv4.gateway 192.168.1.1 \
    ipv4.dns "8.8.8.8" \
    ipv4.method manual

sudo nmcli con up "<YOUR_WIFI_SSID>"
hostname -I
```

### Step 5: Configure SSH on Your Computer

Add an entry to `~/.ssh/config`:

```
Host jetson
    HostName 192.168.1.100
    User <jetson-user>
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

> `StrictHostKeyChecking no` / `UserKnownHostsFile /dev/null` are convenient on a
> trusted home LAN where the Jetson is re-imaged often, but they disable
> host-key verification — omit them if you want the security check.

### Step 6: Test

```bash
ssh jetson
```

---

## Key-Based Login

Copy your **public** key to the Jetson so you don't need a password:

```bash
# From your computer (easiest)
ssh-copy-id -i ~/.ssh/id_ed25519.pub jetson
```

Or manually, on the Jetson:

```bash
mkdir -p ~/.ssh
echo "<YOUR_PUBLIC_KEY>" >> ~/.ssh/authorized_keys   # contents of id_ed25519.pub
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

Don't have a key yet? Generate one on your computer: `ssh-keygen -t ed25519`.

---

## Troubleshooting

### Cannot Connect (Timeout)

1. Check the Jetson's IP (`hostname -I` on the Jetson).
2. Update `HostName` in `~/.ssh/config` if it changed.
3. Verify both machines are on the same network: `ping <jetson-ip>`.

### IP Keeps Changing

Set a static IP (Step 4) or reserve one in your router's DHCP settings by MAC
address.

### Permission Denied

Re-add your public key to `~/.ssh/authorized_keys` on the Jetson (see
[Key-Based Login](#key-based-login)) and check the `~/.ssh` permissions above.

### SSH Not Running

```bash
sudo systemctl enable ssh
sudo systemctl start ssh
```

### Network Conflict (Ethernet vs WiFi)

If a wired connection shadows WiFi, disable the one you're not using:

```bash
nmcli device status                 # find the interface name
sudo nmcli device disconnect <iface>
```

---

## Useful Commands

```bash
# On the Jetson
nmcli con show                  # all connections
nmcli con show --active         # active connection
nmcli device status             # device/interface status
ip addr show                    # IP addresses
sudo systemctl status ssh       # SSH status

# On your computer
ssh -v jetson                   # verbose connect (debugging)
scp file.txt jetson:~/          # copy to Jetson
scp jetson:~/file.txt .         # copy from Jetson
ssh jetson "command here"       # run a remote command
```
