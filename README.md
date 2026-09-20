# SpaceOS

SpaceOS is a personal image-based Linux distribution built on Fedora Bootc 44. It uses Sway as its graphical
environment, is delivered as an OCI image, and receives transactional system updates through `bootc`. This
repository contains the system definition, desktop configuration, GHCR publishing automation, and the process used
to build an Anaconda installer ISO.

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

Installer images are available from this repository's **Releases** page. An ISO is produced only for official
releases tagged as `vMAJOR.MINOR.PATCH`.

1. Download `SpaceOS-vX.Y.Z-x86_64.iso` and its corresponding `.sha256` file from GitHub Releases.
2. Verify the checksum:

   ```bash
   sha256sum --check SpaceOS-vX.Y.Z-x86_64.iso.sha256
   ```

3. Write the ISO to a USB drive using a tool such as Fedora Media Writer.
4. Boot the computer from the prepared installation media.
5. Complete the installation using the graphical Anaconda installer.

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
is rebuilt and `auto` is moved to the resulting image. Automatic rebuilds do not create an ISO or a GitHub Release.

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
| Sway | Tiling Wayland compositor compatible with the i3 configuration model. |
| Waybar | Status bar showing workspaces, network, audio, battery, and update state. |
| Rofi | Application launcher. |
| Alacritty | GPU-accelerated terminal emulator. |
| greetd + tuigreet | Lightweight login manager used to start the Sway session. |
| Ayu Dark / Ayu Light | Matching GTK, terminal, Waybar, and Rofi themes. |
| Plymouth | Graphical boot screen, including the LUKS unlock prompt. |

### Applications

| Software | Description |
|---|---|
| Firefox | Web browser. |
| Thunderbird | Email and calendar client. |
| Signal Desktop | Signal messenger distributed as an AppImage. |
| Teams for Linux | Unofficial Microsoft Teams client. |
| ChatGPT | ChatGPT desktop application for Linux. |
| qBittorrent | BitTorrent client. |
| VLC | Multimedia player. |
| GIMP | Raster graphics editor. |

### Terminal and development

| Software | Description |
|---|---|
| Fish | Interactive shell with rich suggestions and completions. |
| Neovim | Text editor with the SpaceOS development configuration. |
| tmux | Terminal multiplexer. |
| Midnight Commander | Two-panel terminal file manager. |
| Git | Version control system. |
| lazygit | Terminal user interface for Git. |
| Go | Go compiler and development toolchain. |
| uv | Fast Python project and package manager. |
| jq | Command-line JSON processor. |
| Codex | OpenAI coding agent for the terminal. |
| GitHub Copilot CLI | GitHub coding assistant for the terminal. |
| opencommit | Generates commit messages from staged changes. |

### Containers and system tools

| Software | Description |
|---|---|
| Podman | Daemonless OCI container runtime and image builder. |
| Docker Engine and CLI | Container environment compatible with the Docker ecosystem. |
| Docker Buildx | Extended container image build tooling. |
| Docker Compose | Definition and orchestration of multi-container environments. |
| Wiremix | Terminal mixer for PipeWire. |
| brightnessctl | Display brightness control. |
| grim + slurp + swappy | Wayland screenshot capture, region selection, and annotation. |
| SpaceOS Update | Custom automatic scheduling and status integration around native bootc updates. |
| DisplayLink/EVDI | Support for DisplayLink adapters and docking stations. |

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
| `Mod + Shift + R` | Reload the Sway configuration. |

### Windows and workspaces

| Shortcut | Action |
|---|---|
| `Mod + A` / `Mod + F` | Focus the previous/next window. |
| `Mod + Shift + A` / `Mod + Shift + F` | Swap the focused window with the previous/next one. |
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
