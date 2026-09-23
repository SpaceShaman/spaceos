ARG FEDORA_VERSION=44
ARG BASE_IMAGE=quay.io/fedora/fedora-bootc:${FEDORA_VERSION}
ARG SPACEOS_VERSION=0.0.0-devel
ARG SPACEOS_BUILD_ID=local

# ============================================================
# Build DisplayLink EVDI kernel module
# ============================================================

FROM ${BASE_IMAGE} AS displaylink-builder

ADD https://negativo17.org/repos/fedora-multimedia.repo /etc/yum.repos.d/negativo17-fedora-multimedia.repo

RUN set -eux \
    && KERNEL_VERSION="$(find /usr/lib/modules \
        -mindepth 1 -maxdepth 1 -type d \
        -printf '%f\n' | head -n1)" \
    && echo "Building EVDI for kernel: ${KERNEL_VERSION}" \
    # fedora-repos-archive is important when the bootc image
    # contains a kernel slightly older than the current Fedora repos.
    && dnf5 -y install \
        fedora-repos-archive \
        akmods \
        gcc \
        gcc-c++ \
        make \
        dnf5-plugins \
        "kernel-devel-${KERNEL_VERSION}" \
    && dnf5 -y install \
        kmod-evdi \
        akmod-evdi \
    # UBlue explicitly uses these flags for EVDI.
    && export CFLAGS="-fno-pie -no-pie" \
    && akmods \
        --force \
        --kernels "${KERNEL_VERSION}" \
        --kmod evdi \
    # Fail the image build if EVDI was not actually produced.
    && modinfo \
        "/usr/lib/modules/${KERNEL_VERSION}/extra/evdi/evdi.ko.xz" \
    # Keep only the resulting binary kmod RPM.
    && mkdir -p /out/kmod \
    && find /var/cache/akmods/evdi \
        -type f \
        -name '*.rpm' \
        -exec cp -v -t /out/kmod/ {} + \
    # Download userspace part of DisplayLink.
    && mkdir -p /out/userspace \
    && dnf5 download \
        --destdir=/out/userspace \
        libevdi \
        displaylink \
    && find /out -type f -print


# ============================================================
# SpaceOS
# ============================================================

FROM ${BASE_IMAGE}

COPY --from=displaylink-builder /out /tmp/displaylink

RUN set -eux \
    && dnf5 -y install \
        /tmp/displaylink/userspace/*.rpm \
        /tmp/displaylink/kmod/*.rpm \
    && KERNEL_VERSION="$(find /usr/lib/modules \
        -mindepth 1 -maxdepth 1 -type d \
        -printf '%f\n' | head -n1)" \
    && depmod -a "${KERNEL_VERSION}" \
    && rm -rf /tmp/displaylink


# ============================================================
# Package repositories
# ============================================================

ARG CHATGPT_RPM_URL=https://persistent.oaistatic.com/codex-app-prod/linux/rpm/latest/chatgpt.x86_64.rpm

ADD --checksum=sha256:b80dd8b308a675c23d7263b34c52d6b3886a4e05257c1f8d4f3c0c5cd23a31f4 \
    https://github.com/usebruno/bruno/releases/download/v4.1.0/bruno_4.1.0_x86_64_linux.rpm /tmp/bruno.rpm

ADD --chmod=0644 \
    https://repo.teamsforlinux.de/teams-for-linux.asc /etc/pki/rpm-gpg/teams-for-linux.asc

RUN set -eux \
    && rpm --import /etc/pki/rpm-gpg/teams-for-linux.asc \
    && dnf5 install -y \
        'dnf5-command(config-manager)' \
    && dnf5 config-manager addrepo \
        --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo \
    && dnf5 config-manager addrepo \
        --from-repofile https://repo.teamsforlinux.de/rpm/teams-for-linux.repo


# ============================================================
# Fedora and RPM packages
# ============================================================

RUN set -eux \
    && : "Firmware" \
    && dnf5 install -y --allow-downgrade --allowerasing \
        linux-firmware-whence \
        iwlwifi-mvm-firmware \
    && : "System and desktop" \
    && dnf5 install -y \
        glibc-langpack-pl \
        linux-firmware \
        NetworkManager-wifi \
        fuse-libs \
        greetd \
        greetd-selinux \
        tuigreet \
        sway \
        waybar \
        plymouth \
        plymouth-plugin-two-step \
        plymouth-theme-spinner \
        librsvg2-tools \
        adw-gtk3-theme \
        xdg-desktop-portal-gtk \
        wiremix \
        brightnessctl \
        rofi \
        alacritty \
        grim \
        slurp \
        swappy \
    && : "Development and command-line tools" \
    && dnf5 install -y \
        jq \
        fish \
        nvim \
        mc \
        git \
        tmux \
        golang \
        uv \
        rclone \
        rsync \
    && : "Container tools" \
    && dnf5 install -y \
        podman \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
    && : "Desktop applications" \
    && dnf5 install -y \
        firefox \
        "${CHATGPT_RPM_URL}" \
        /tmp/bruno.rpm \
        teams-for-linux \
        thunderbird \
        qbittorrent \
        vlc \
        gimp \
        filezilla \
    && rm -f /tmp/bruno.rpm \
    && dnf5 clean all


# ============================================================
# Standalone applications and tools
# ============================================================

ADD --chmod=0755 \
    https://updates.signal.org/desktop/signal-desktop.AppImage /usr/bin/signal-desktop

ADD --chmod=0644 \
    https://raw.githubusercontent.com/signalapp/Signal-Desktop/main/build/icons/png/512x512.png /usr/share/icons/hicolor/512x512/apps/signal-desktop.png

ADD --checksum=sha256:50b2f0a8c533d607e5a8a1f478fe78d5585317178bd86456659c049965a8945d \
    https://github.com/zk-org/zk/releases/download/v0.15.6/zk-v0.15.6-linux-amd64.tar.gz /tmp/zk.tar.gz

ADD --checksum=sha256:02beacbcda0fa342e50ae3480ba8147307353af3fb28e1d5f790e02329c201a6 \
    https://github.com/jesseduffield/lazygit/releases/download/v0.65.1/lazygit_0.65.1_linux_x86_64.tar.gz /tmp/lazygit.tar.gz

RUN set -eux \
    && tar -xzf /tmp/zk.tar.gz -C /usr/bin zk \
    && tar -xzf /tmp/lazygit.tar.gz -C /usr/bin lazygit \
    && chmod 0755 /usr/bin/zk /usr/bin/lazygit \
    && zk --version \
    && lazygit --version \
    && rm -f /tmp/zk.tar.gz /tmp/lazygit.tar.gz


# ============================================================
# Global npm tools
# ============================================================

RUN set -eux \
    && mkdir -p /tmp/npm-cache \
    && npm install -g \
        --prefix /usr \
        --cache /tmp/npm-cache \
        @openai/codex \
        @github/copilot \
        opencommit \
    && rm -rf /tmp/npm-cache


# ============================================================
# System configuration
# ============================================================

COPY kargs.d/ /usr/lib/bootc/kargs.d/

COPY . /etc/spaceos/
RUN cp -asf --remove-destination /etc/spaceos/rootfs/. /


# ============================================================
# Branding and fonts
# ============================================================

COPY assets/spaceos-logo-dark.svg /usr/share/spaceos/spaceos-logo.svg

ADD --chmod=0644 \
    https://raw.githubusercontent.com/googlefonts/noto-emoji/v2.051/fonts/NotoColorEmoji.ttf /usr/share/fonts/noto-emoji/NotoColorEmoji.ttf

RUN set -eux \
    && rsvg-convert \
        --width 465 \
        --height 120 \
        --output /usr/share/plymouth/themes/spinner/watermark.png \
        /usr/share/spaceos/spaceos-logo.svg \
    && sed -i \
        -e 's/^WatermarkHorizontalAlignment=.*/WatermarkHorizontalAlignment=.5/' \
        -e 's/^WatermarkVerticalAlignment=.*/WatermarkVerticalAlignment=.36/' \
        -e 's/^DialogHorizontalAlignment=.*/DialogHorizontalAlignment=.5/' \
        -e 's/^DialogVerticalAlignment=.*/DialogVerticalAlignment=.53/' \
        -e 's/^HorizontalAlignment=.*/HorizontalAlignment=.5/' \
        -e 's/^VerticalAlignment=.*/VerticalAlignment=.68/' \
        /usr/share/plymouth/themes/spinner/spinner.plymouth \
    && grep -q '^WatermarkVerticalAlignment=.36$' \
        /usr/share/plymouth/themes/spinner/spinner.plymouth \
    && grep -q '^DialogVerticalAlignment=.53$' \
        /usr/share/plymouth/themes/spinner/spinner.plymouth \
    && grep -q '^VerticalAlignment=.68$' \
        /usr/share/plymouth/themes/spinner/spinner.plymouth \
    && plymouth-set-default-theme spinner

RUN fc-cache -f -v


# ============================================================
# Initramfs
# ============================================================

RUN set -eux \
    && KERNEL_VERSION="$(find /usr/lib/modules \
        -mindepth 1 -maxdepth 1 -type d \
        -printf '%f\n' | head -n1)" \
    && env DRACUT_NO_XATTR=1 \
        dracut -vf "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img" "${KERNEL_VERSION}"


# ============================================================
# OS metadata
# ============================================================

ARG SPACEOS_VERSION
ARG SPACEOS_BUILD_ID

RUN printf '%s\n' \
    'NAME="SpaceOS"' \
    "VERSION=\"${SPACEOS_VERSION}\"" \
    'ID=spaceos' \
    'ID_LIKE=fedora' \
    "VERSION_ID=\"${SPACEOS_VERSION}\"" \
    "BUILD_ID=\"${SPACEOS_BUILD_ID}\"" \
    "PRETTY_NAME=\"SpaceOS ${SPACEOS_VERSION}\"" \
    'HOME_URL="https://github.com/SpaceShaman/spaceos"' \
    'DOCUMENTATION_URL="https://github.com/SpaceShaman/spaceos"' \
    'BUG_REPORT_URL="https://github.com/SpaceShaman/spaceos/issues"' \
    >/usr/lib/os-release \
    && ln -sfn ../usr/lib/os-release /etc/os-release \
    && rm -f /etc/system-release \
    && printf 'SpaceOS\n' >/etc/system-release


# ============================================================
# Services and validation
# ============================================================

RUN systemctl enable \
    displaylink.service \
    docker.service \
    containerd.service \
    greetd.service \
    && systemctl set-default graphical.target

RUN bootc container lint
