# webinterface-onboot (Self-Contained Backup & Guide)

This directory contains a full local backup of the upstream [`rM-self-serve/webinterface-onboot`](https://github.com/rM-self-serve/webinterface-onboot) project, used to keep the reMarkable 2 internal USB web server (`http://10.11.99.1:80`) active permanently over Wi-Fi and without a physical USB-C cable.

When active, **SSH Explorer** automatically uses this loopback server to import PDFs live into your library in under 1 second with **zero restarts** (`⚡ No-Restart Mode`).

---

## Included Files

- **`webinterface-onboot`**: The main executable script managing binary string patching (`usb0 -> usbF`), IP persistence in `/etc/ifplugd/ifplugd.action`, and service execution.
- **`webinterface-onboot.service`**: Systemd unit to enable loopback at boot (`systemctl enable webinterface-onboot.service`).
- **`install-webint-ob.sh`**: Official installation script.
- **`UPSTREAM_README.md`**: Original documentation from upstream repository.
- **`LICENSE.md`**: MIT License from upstream author.

---

## Installation Methods

### Method 1: Using Toltec (Recommended if you have Toltec)

If Toltec is installed on your tablet, run directly on the device via SSH:
```bash
opkg update
opkg install webinterface-onboot
systemctl enable --now webinterface-onboot
```

---

### Method 2: Offline / Manual Installation from this Repository

You can install `webinterface-onboot` directly onto the tablet using the files in this directory without needing internet access on the tablet:

```bash
# 1. Copy files to reMarkable
scp tools/webinterface-onboot/webinterface-onboot root@remarkable:/home/root/.local/bin/
scp tools/webinterface-onboot/webinterface-onboot.service root@remarkable:/lib/systemd/system/

# 2. Make executable and apply patch
ssh root@remarkable "chmod +x /home/root/.local/bin/webinterface-onboot"
ssh root@remarkable "/home/root/.local/bin/webinterface-onboot apply-hack -y"
ssh root@remarkable "/home/root/.local/bin/webinterface-onboot apply-prstip -y"

# 3. Enable and start systemd service
ssh root@remarkable "systemctl daemon-reload && systemctl enable --now webinterface-onboot"

# 4. Restart xochitl once to load the patched binary
ssh root@remarkable "systemctl restart xochitl"
```

---

## Verifying the Status

On the device:
```bash
/home/root/.local/bin/webinterface-onboot --status
```
Or check with `curl` directly:
```bash
curl -I http://10.11.99.1/
```
Inside **SSH Explorer**, the top bar will display **`[⚡ No-Restart]`** and the connection setup view will indicate that loopback is active on `10.11.99.1`.

---

## Uninstallation / Revert

To restore the 100% stock configuration:
```bash
ssh root@remarkable "/home/root/.local/bin/webinterface-onboot revert-hack -b -y"
ssh root@remarkable "/home/root/.local/bin/webinterface-onboot revert-prstip -y"
ssh root@remarkable "systemctl disable --now webinterface-onboot"
ssh root@remarkable "systemctl restart xochitl"
```
