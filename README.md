<p align="center">
  <img src="assets/spaceos-logo-light.svg#gh-light-mode-only" alt="SpaceOS" width="465">
  <img src="assets/spaceos-logo-dark.svg#gh-dark-mode-only" alt="SpaceOS" width="465">
</p>

SpaceOS is a personal image-based Linux distribution built on Fedora Bootc 44. It uses Sway as its graphical
environment, is delivered as an OCI image, and receives transactional system updates through `bootc`. This
repository contains the system definition, desktop configuration, GHCR publishing automation, and a script for
building an Anaconda installer ISO locally.

For the story behind the project, see
[How and why I built my own bootc-based Linux distribution](https://spaceshaman.github.io/posts/how-and-why-i-built-my-own-bootc-based-linux-distribution/).
The article covers the path from the initial idea to an encrypted dual-boot installation, DisplayLink support, and
the CI/CD update pipeline used by SpaceOS.

> [!IMPORTANT]
> SpaceOS is built specifically for my hardware, workflow, and personal preferences. I do not recommend using it
> directly as a general-purpose distribution. You are, however, encouraged to fork this repository and use it as a
> starting point for building your own bootc-based distribution.

## Highlights

- Fedora Bootc 44 base image.
- Transactional system images published to GitHub Container Registry.
- Lightweight desktop built around Sway, Waybar, Rofi, and Alacritty.
- Graphical installer based on Anaconda.
- Background updates without forced restarts.
- Previous deployment available for rollback.
- DisplayLink support with an EVDI module built for the image kernel.
- Custom Plymouth branding for the boot and LUKS unlock screens.
- A consistent visual style based on Ayu Dark and Ayu Light across the desktop and supported applications.

## Installation

### Installing from an ISO

Installer images are not published as GitHub Release assets because the complete ISO exceeds GitHub's per-file
size limit. Build the installer locally from the repository instead. The script requires Podman, root access through
`sudo`, and enough free disk space for the container images and resulting ISO.

1. Clone the repository and check out the release tag to install:

   ```bash
   git clone https://github.com/SpaceShaman/spaceos.git
   cd spaceos
   git checkout vX.Y.Z
   ```

2. Build the ISO. By default, the script reads the latest local release tag for the installer version and embeds the
   `ghcr.io/spaceshaman/spaceos:auto` image so that the installed system continues tracking the automatic update
   channel:

   ```bash
   ./scripts/build-installer-iso.sh
   ```

   To select a version explicitly, use `VERSION` without the leading `v`:

   ```bash
   VERSION=X.Y.Z ./scripts/build-installer-iso.sh
   ```

   `BASE_IMAGE`, `PAYLOAD_IMAGE`, `BUILDER_IMAGE`, and `OUTPUT_DIR` can also be overridden when testing a different
   image or build environment.

3. Verify the generated checksum:

   ```bash
   cd output/installer-vX.Y.Z
   sha256sum --check SpaceOS-vX.Y.Z-x86_64.iso.sha256
   ```

4. Write the ISO to a USB drive using a tool such as Fedora Media Writer.
5. Boot the computer from the prepared installation media.
6. Complete the installation using the graphical Anaconda installer.

The SpaceOS image used for installation is embedded in the ISO. After installation, the system tracks the `auto`
channel in GHCR, so future updates do not require the installer media.

### Switching an existing bootc system

An existing bootc-compatible system can switch directly to SpaceOS:

```bash
sudo bootc switch ghcr.io/spaceshaman/spaceos:auto
sudo reboot
```

Use the `stable` channel if the system should receive official SpaceOS releases only:

```bash
sudo bootc switch ghcr.io/spaceshaman/spaceos:stable
sudo reboot
```

Back up important data before switching. SpaceOS contains configuration tailored to specific hardware and may
change assumptions about services, the desktop, drivers, or the target system layout.

### Installing to prepared filesystems

Use [`bootc install to-filesystem`](https://bootc.dev/bootc/man/bootc-install-to-filesystem.8.html) to install SpaceOS on filesystems that have already been created and formatted. Replace the device paths below, verify them carefully, and run:

```bash
set -euo pipefail

ROOT_DEVICE="/dev/ROOT_DEVICE"
BOOT_DEVICE="/dev/BOOT_DEVICE"
EFI_DEVICE="/dev/EFI_DEVICE"
TARGET="/mnt/spaceos"
IMAGE="ghcr.io/spaceshaman/spaceos:auto"

sudo mkdir -p "$TARGET"
sudo mount "$ROOT_DEVICE" "$TARGET"
sudo mkdir -p "$TARGET/boot"
sudo mount "$BOOT_DEVICE" "$TARGET/boot"
sudo mkdir -p "$TARGET/boot/efi"
sudo mount "$EFI_DEVICE" "$TARGET/boot/efi"

findmnt -R "$TARGET"

ROOT_UUID="$(sudo blkid -s UUID -o value "$ROOT_DEVICE")"
BOOT_UUID="$(sudo blkid -s UUID -o value "$BOOT_DEVICE")"

sudo podman pull "$IMAGE"
sudo podman run --rm --privileged \
  --pid=host \
  --ipc=host \
  --security-opt label=type:unconfined_t \
  -v /dev:/dev \
  -v /var/lib/containers:/var/lib/containers \
  -v "${TARGET}:/target" \
  "$IMAGE" \
  bootc install to-filesystem \
    --bootloader=grub \
    --root-mount-spec="UUID=${ROOT_UUID}" \
    --boot-mount-spec="UUID=${BOOT_UUID}" \
    /target
```

The mounts select the root, `/boot`, and EFI filesystems, while the UUID options tell the installed system how to find root and `/boot` during startup. This example uses a separate `/boot`; other storage layouts may require different mount options or additional `--karg` arguments. Change `auto` to `stable` to follow official releases only.

## GHCR images and tags

Images are published as:

```text
ghcr.io/spaceshaman/spaceos
```

| Tag | Meaning | Retention |
|---|---|---|
| `v0.1.3` | Immutable image for a specific release | Kept indefinitely |
| `stable` | Latest official SpaceOS release | Moving tag |
| `latest` | Alias for the latest official release | Moving tag |
| `auto` | Latest release or latest rebuild following a Fedora update | Moving tag |
| `auto-v0.1.3-20260920-abcdef123456` | A specific automatic rebuild | Latest five |

Publishing a new `vX.Y.Z` tag moves `stable`, `latest`, and `auto` to the new release. Once a week, GitHub Actions
checks the digest of `quay.io/fedora/fedora-bootc:44`. If the base changed, the source of the latest SpaceOS release
is rebuilt and `auto` is moved to the resulting image. GitHub Actions does not build or publish installer ISOs.

All `vX.Y.Z` images remain in the registry. Only the five newest dated automatic rebuilds are retained.

## System updates

SpaceOS does not use an update mechanism that automatically reboots the computer after finding a new image. A
custom systemd timer checks for updates every hour, with a randomized delay of up to 10 minutes.

The update process works as follows:

1. The system checks the channel selected during installation or the latest `bootc switch`.
2. The update is deferred on a metered connection, when the battery is below 30%, or while the system load is high.
3. A new image is downloaded and prepared as a staged deployment.
4. The running system is neither restarted nor modified.
5. Waybar displays an indicator when a new deployment is ready.
6. The update is applied during a normal restart initiated by the user.

Updates can also be inspected and managed directly with `bootc`:

```bash
bootc status
sudo bootc upgrade --check
sudo bootc upgrade
```

`bootc status` shows the currently booted image, any staged update, and the rollback deployment.
`bootc upgrade --check` checks registry metadata without downloading and staging the complete update. A regular
`bootc upgrade` downloads the new image and stages it for the next restart, but does not restart the computer.

Automatic updater logs are available through:

```bash
journalctl -u spaceos-update.service
```

Inspect the current, staged, and rollback deployments with:

```bash
bootc status
```

## Included software

The following tables list the main applications and tools added by SpaceOS. They do not include system-level
dependencies inherited from the Fedora base image.

### Desktop environment

| Software | Description |
|---|---|
| [Sway](https://github.com/swaywm/sway) | Tiling Wayland compositor compatible with the i3 configuration model. |
| [swayidle](https://github.com/swaywm/swayidle) | Turns displays off after 5 minutes of inactivity and restores them on input. |
| [Waybar](https://github.com/Alexays/Waybar) | Status bar showing workspaces, network, audio, battery, and update state. |
| [Rofi](https://github.com/davatorium/rofi) | Application launcher. |
| [Alacritty](https://github.com/alacritty/alacritty) | GPU-accelerated terminal emulator. |
| [greetd](https://git.sr.ht/~kennylevinsen/greetd) + [tuigreet](https://github.com/apognu/tuigreet) | Lightweight login manager used to start the Sway session. |
| [Ayu Dark / Ayu Light](https://github.com/ayu-theme/ayu-colors) | Matching GTK, terminal, Waybar, and Rofi themes. |
| [Plymouth](https://www.freedesktop.org/wiki/Software/Plymouth/) | Graphical boot screen, including the LUKS unlock prompt. |

### Applications

| Software | Description |
|---|---|
| [Firefox](https://www.firefox.com/) | Web browser. |
| [Thunderbird](https://github.com/thunderbird/thunderbird-desktop) | Email and calendar client. |
| [Signal Desktop](https://github.com/signalapp/Signal-Desktop) | Signal messenger distributed as an AppImage. |
| [Teams for Linux](https://github.com/IsmaelMartinez/teams-for-linux) | Unofficial Microsoft Teams client. |
| [ChatGPT](https://chatgpt.com/download) | ChatGPT desktop application for Linux. |
| [Bruno](https://github.com/usebruno/bruno) | API client for designing and testing HTTP requests. |
| [qBittorrent](https://github.com/qbittorrent/qBittorrent) | BitTorrent client. |
| [VLC](https://github.com/videolan/vlc) | Multimedia player. |
| [GIMP](https://github.com/GNOME/gimp) | Raster graphics editor. |
| [FileZilla](https://filezilla-project.org/) | FTP, FTPS, and SFTP client. |

### Terminal and development

| Software | Description |
|---|---|
| [Fish](https://github.com/fish-shell/fish-shell) | Interactive shell with rich suggestions and completions. |
| [Neovim](https://github.com/neovim/neovim) | Text editor with the SpaceOS development configuration. |
| [tmux](https://github.com/tmux/tmux) | Terminal multiplexer. |
| [Midnight Commander](https://github.com/MidnightCommander/mc) | Two-panel terminal file manager. |
| [Git](https://github.com/git/git) | Version control system. |
| [lazygit](https://github.com/jesseduffield/lazygit) | Terminal user interface for Git. |
| [Go](https://github.com/golang/go) | Go compiler and development toolchain. |
| [uv](https://github.com/astral-sh/uv) | Fast Python project and package manager. |
| [rclone](https://github.com/rclone/rclone) | Command-line sync tool for cloud storage and remote filesystems. |
| [rsync](https://github.com/RsyncProject/rsync) | Efficient local and remote file synchronization utility. |
| [zk](https://github.com/zk-org/zk) | Plain-text note-taking assistant with a Zettelkasten workflow. |
| [jq](https://github.com/jqlang/jq) | Command-line JSON processor. |
| [Codex](https://github.com/openai/codex) | OpenAI coding agent for the terminal. |
| [GitHub Copilot CLI](https://github.com/github/copilot-cli) | GitHub coding assistant for the terminal. |
| [opencommit](https://github.com/di-sukharev/opencommit) | Generates commit messages from staged changes. |

### Containers and system tools

| Software | Description |
|---|---|
| [Podman](https://github.com/containers/podman) | Daemonless OCI container runtime and image builder. |
| [Docker](https://github.com/docker/docker-ce) | Container environment compatible with the Docker ecosystem. |
| [Docker Compose](https://github.com/docker/compose) | Definition and orchestration of multi-container environments. |
| [Docker Buildx](https://github.com/docker/buildx) | Extended Docker image builder with multi-platform build support. |
| [Wiremix](https://github.com/tsowell/wiremix) | Terminal mixer for PipeWire. |
| [brightnessctl](https://github.com/Hummer12007/brightnessctl) | Display brightness control. |
| [grim](https://github.com/emersion/grim) + [slurp](https://github.com/emersion/slurp) + [swappy](https://github.com/jtheoof/swappy) | Wayland screenshot capture, region selection, and annotation. |
| [DisplayLink](https://www.synaptics.com/products/displaylink-graphics) / [EVDI](https://github.com/DisplayLink/evdi) | Support for DisplayLink adapters and docking stations. |
| [Netcat](https://nmap.org/ncat/) (`nc`) | Command-line utility for TCP and UDP connections. |

## Keyboard shortcuts

`Mod` refers to the Super/Windows key.

### Applications and session

| Shortcut | Action |
|---|---|
| `Mod + Enter` | Open Alacritty. |
| `Mod + R` | Open the Rofi application launcher. |
| `Mod + B` | Open Firefox. |
| `Mod + G` | Open ChatGPT. |
| `Mod + T` | Toggle the light/dark theme. |
| `Mod + Q` | Close the focused window. |
| `Mod + Shift + Q` | Power off the system. |
| `Mod + Shift + R` | Reload the Sway configuration. |

### Windows and workspaces

| Shortcut | Action |
|---|---|
| `Mod + A` / `Mod + F` | Focus the previous/next window. |
| `Mod + Shift + A` / `Mod + Shift + F` | Swap the focused window with the previous/next one. |
| `Mod + Ctrl + J` / `Mod + Ctrl + ;` | Shrink/grow the focused window's width by 50 px. |
| `Mod + Ctrl + K` / `Mod + Ctrl + L` | Shrink/grow the focused window's height by 50 px. |
| `Mod + S` / `Mod + D` | Focus the previous/next workspace. |
| `Mod + Shift + S` / `Mod + Shift + D` | Move the focused window to the previous/next workspace. |
| `Mod + J` / `Mod + ;` | Focus the output to the left/right. |
| `Mod + L` / `Mod + K` | Focus the output above/below. |
| `Mod + Shift + J` / `Mod + Shift + ;` | Move the focused window to the output on the left/right. |
| `Mod + Shift + L` / `Mod + Shift + K` | Move the focused window to the output above/below. |

### Screenshots and media

| Shortcut | Action |
|---|---|
| `Print Screen` | Select a region, capture it, and open it in Swappy. |
| `Shift + Print Screen` | Capture the full screen and open it in Swappy. |
| `XF86AudioRaiseVolume` / `XF86AudioLowerVolume` | Increase/decrease audio volume. |
| `XF86AudioMute` | Toggle audio mute. |
| `XF86MonBrightnessUp` / `XF86MonBrightnessDown` | Increase/decrease display brightness. |

## Dynamic window and workspace management

Workspaces are independent on each output and numbered consecutively from `1`. Moving backward from the first workspace inserts a new first workspace and shifts the existing ones; empty workspaces are removed by Sway, then the remaining workspaces are renumbered immediately. Forward and backward navigation creates a workspace only when the current workspace contains a window, and moving a window never leaves an unnecessary empty workspace behind.

Window focus and swapping cycle through the windows on the focused workspace. A background Sway listener adjusts the next tiling split after each window opens or closes: it uses the longer screen axis for one or an odd number of windows, and the other axis for an even number, so the layout alternates automatically with the window count.
