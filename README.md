# SSH Explorer for reMarkable 2

[![rm2](https://img.shields.io/badge/rM2-supported-green)](https://remarkable.com/products/remarkable-2)

**SSH Explorer** is a native file browser and PDF importer for **reMarkable** tablets, built on the [**AppLoad**](https://github.com/asivery/rm-appload) ([XOVI](https://github.com/asivery/xovi)) ecosystem. It allows you to browse remote file systems over SSH and download PDF documents directly into your reMarkable library.

<p align="center">
  <img src="res/screenshot.webp" alt="SSH Explorer on reMarkable 2" width="550" />
</p>

---

## Features

- **E-Ink Optimized UI:** High-contrast monochrome interface designed for minimal flicker, with dedicated Page Up / Page Down controls.
- **On-Screen Touch Keyboard:** Integrated virtual keyboard for typing hosts, paths, and credentials directly on the tablet.
- **Connection Profiles:** Save, test, and delete multiple SSH profiles stored in `~/.config/ssh-explorer/config.json`.
- **Fast Directory Traversal & Filters:** Browse remote folders with an integrated real-time search bar, quick filter toggles for *PDFs Only* and *Hidden Files* (dotfiles), plus human-readable file sizes.
- **Smart No-Restart PDF Import (USB Loopback):**
  - **Live In-Memory Refresh:** Automatically uploads documents through reMarkable's internal web server (`http://10.11.99.1/upload` via local loopback). Documents appear in the `xochitl` library **instantly without restarting the UI** and without closing SSH Explorer!
  - **Graceful Fallback:** If the internal web server is inactive, it seamlessly falls back to direct storage creation (`~/.local/share/remarkable/xochitl/`) with the 1-tap **Restart xochitl now** option.
  - **Real-Time Loopback Diagnostics:** Top-bar status badge and Setup panel let you test and activate loopback directly from the tablet.
- **Lightweight & Self-Contained:** No Python, Node.js, or heavyweight runtimes required on device. Powered by standard POSIX shell tools, Dropbear, and XOVI's CommandExecutor.

---

## Device Requirements

* **Device:** reMarkable 2 (OS 3.x / Yocto Linux armv7).
* **Installed Vellum packages:**
  * `appload`
  * `xovi` & `xovi-extensions`
  * `qt-command-executor`
  * `qt-resource-rebuilder`
* **SSH Client:** Dropbear (`dbclient` / `ssh`) with configured identity keys (e.g. `/home/root/.ssh/id_dropbear` or `id_rsa`).

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    xochitl (reMarkable OS UI)                   │
│                    ▲                         │                  │
│   [Live Model Sync]│                         │ AppLoad          │
│                    │                         ▼ Extension        │
│          ┌──────────────────────────────────────────────┐       │
│          │                 SSH Explorer                 │       │
│          │     (QML: ConnectionView, ExplorerView,      │       │
│          │      VirtualKeyboard, ImportModal)           │       │
│          └──────────────────────┬───────────────────────┘       │
│                                 │ net.asivery.CommandExecutor   │
│          ┌──────────────────────▼───────────────────────┐       │
│          │                ssh-helper.sh                 │       │
│          └───────────┬───────────────────┬──────────────┘       │
│                      │                   │                      │
│             [Loopback HTTP POST]         │                      │
│              http://10.11.99.1/upload    │                      │
│                      │                   │                      │
└──────────────────────┼───────────────────┼──────────────────────┘
                       │                   │
             [ Dropbear SSH / SCP ]        │ [ Direct Storage Write ]
                       │                   ▼   (Fallback)
                       │          reMarkable Storage
                       │       (/home/root/.../xochitl)
                       ▼
             [ Remote SSH Server ]
```

---

## No-Restart Library Refresh (`norestart` Branch)

In stock reMarkable OS, writing documents directly to `/home/root/.local/share/remarkable/xochitl/` does not automatically update the on-screen library because `xochitl` does not watch the directory for changes. To refresh the library, users traditionally had to restart the whole `xochitl` service (`systemctl restart xochitl`), which terminates all open apps, causes screen flashing, and takes several seconds.

The `norestart` branch implements a **USB Web Server Loopback** architecture to refresh the library without any restart:

### How it Works:
1. `xochitl` contains an internal HTTP web server (exposed on port `80` when the USB Web Interface is active).
2. When a document is uploaded via `POST /upload`, `xochitl` processes the upload directly inside its own memory space and notifies its internal Qt document model.
3. Instead of requiring a physical computer connected over USB, `ssh-helper.sh` performs an internal loopback request directly from the tablet (`http://10.11.99.1/upload` via `curl`).
4. The document appears immediately on screen in the user's library without restarting `xochitl` and without closing SSH Explorer!

### Loopback Operating Strategies:
* **Strategy 1: Active USB Connection:** If the tablet is connected to a PC via USB and the Web Interface is toggled ON, loopback works out of the box with zero setup.
* **Strategy 2: Standalone Wi-Fi with `webinterface-onboot`:** With community utilities like `webinterface-onboot` or `webinterface-wifi` installed from Toltec, the internal web server runs persistently in the background. SSH Explorer automatically uses it over Wi-Fi without needing a USB cable.
* **Strategy 3: Non-Destructive Loopback Setup:** `ssh-helper.sh` automatically binds `10.11.99.1/32` to the `lo` loopback interface and sets `WebInterfaceEnabled=true` in `xochitl.conf`.
* **Strategy 4: Graceful Fallback:** If port 80 is not listening, SSH Explorer automatically falls back to direct storage creation and provides the classic 1-tap restart button.

### Testing & Diagnostic Tools:
* **In the UI:** Tap **Test Loopback** or **Setup Loopback** in the *SSH Connection Setup* view, or watch the status badge in the top bar (`[⚡ No-Restart]` vs `[Direct-Write]`).
* **From the CLI:**
  ```bash
  # Check web server status and network interfaces
  ./ssh-helper.sh test-loopback

  # Prepare loopback alias and xochitl.conf
  ./ssh-helper.sh enable-loopback

  # Test upload a local PDF file
  ./ssh-helper.sh upload-loopback /path/to/test.pdf "Test Title"

  # Run the full diagnostic & experiment suite
  ./tools/loopback-experiment.sh --full
  ```

---

---

## Quick Start

### 1. Build the Package

Run on your computer (`rcc` required):
```bash
./build.sh
```
This packages QML resources into `dist/ssh-explorer/resources.rcc` and creates `dist/ssh-explorer.tar.gz`.

### 2. Deploy to reMarkable 2

Over USB (default IP `10.11.99.1`):
```bash
./deploy.sh
```

Or specify a Wi-Fi IP address:
```bash
./deploy.sh 192.168.1.150
```

### 3. Launch

1. Open the **AppLoad** launcher on your reMarkable tablet.
2. Tap **SSH Explorer** to launch full screen (or long-press to window).

---

## PC Desktop Preview

Test the interface locally on Linux with the tablet's native resolution:
```bash
cd preview
qmake && make
./preview-app
```

---

## Project Structure

```
ssh-explorer/
├── manifest.json              # AppLoad descriptor
├── application.qrc            # Qt resource descriptor
├── icon.png                   # Launcher icon (200x200)
├── ssh-helper.sh              # POSIX backend helper for SSH commands & import
├── build.sh                   # Build & packaging script
├── deploy.sh                  # One-step SSH deployment script
├── res/
│   └── screenshot.webp        # Application screenshot
├── ui/
│   ├── main.qml               # App root, state coordinator & top bar
│   ├── Style.qml              # E-Ink palette, metrics, and typography
│   ├── qmldir                 # QML module definition
│   ├── ConnectionView.qml     # Profile manager & connection form
│   ├── ExplorerView.qml       # Remote file browser & pagination
│   ├── VirtualKeyboard.qml    # On-screen touch keyboard
│   └── ImportModal.qml        # Download progress & import confirmation modal
└── preview/                   # Linux desktop Qt5 test runner
```
