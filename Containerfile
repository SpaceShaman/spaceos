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

ARG SPACEOS_VERSION
ARG SPACEOS_BUILD_ID

COPY --from=displaylink-builder /out /tmp/displaylink

RUN set -eux \
    && dnf5 -y install \
        /tmp/displaylink/userspace/*.rpm \
        /tmp/displaylink/kmod/*.rpm \
    && KERNEL_VERSION="$(find /usr/lib/modules \
        -mindepth 1 -maxdepth 1 -type d \
        -printf '%f\n' | head -n1)" \
    && depmod -a "${KERNEL_VERSION}" \
    && systemctl enable displaylink.service \
    && rm -rf /tmp/displaylink

ARG CHATGPT_RPM_URL=https://persistent.oaistatic.com/codex-app-prod/linux/rpm/latest/chatgpt.x86_64.rpm

ADD --chmod=0644 \
    https://repo.teamsforlinux.de/teams-for-linux.asc /etc/pki/rpm-gpg/teams-for-linux.asc
RUN rpm --import /etc/pki/rpm-gpg/teams-for-linux.asc

RUN dnf5 install -y \
    'dnf5-command(config-manager)' \
    'dnf5-command(copr)' \
    && dnf5 config-manager addrepo \
        --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo \
    && dnf5 config-manager addrepo \
        --from-repofile https://repo.teamsforlinux.de/rpm/teams-for-linux.repo \
    && dnf5 copr enable -y dejan/lazygit \
    && dnf5 install -y --allow-downgrade --allowerasing \
        linux-firmware-whence \
        iwlwifi-mvm-firmware \
    && dnf5 install -y \
        glibc-langpack-pl \
        linux-firmware \
        NetworkManager-wifi \
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
        jq \
        rofi \
        alacritty \
        fish \
        nvim \
        mc \
        git \
        podman \
        fuse-libs \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        firefox \
        tmux \
        lazygit \
        golang \
        "${CHATGPT_RPM_URL}" \
        uv \
        grim \
        slurp \
        swappy \
        teams-for-linux \
        thunderbird \
        qbittorrent \
        vlc \
        gimp
RUN dnf5 clean all

ADD --chmod=0755 \
    https://updates.signal.org/desktop/signal-desktop.AppImage /usr/bin/signal-desktop

ADD --chmod=0644 \
    https://raw.githubusercontent.com/signalapp/Signal-Desktop/main/build/icons/png/512x512.png /usr/share/icons/hicolor/512x512/apps/signal-desktop.png

RUN systemctl enable \
    docker.service \
    containerd.service

ADD --chmod=0644 \
    https://raw.githubusercontent.com/googlefonts/noto-emoji/v2.051/fonts/NotoColorEmoji.ttf /usr/share/fonts/noto-emoji/NotoColorEmoji.ttf

RUN set -eux \
    && mkdir -p /tmp/npm-cache \
    && npm install -g \
        --prefix /usr \
        --cache /tmp/npm-cache \
        @openai/codex \
        @github/copilot \
        opencommit \
    && rm -rf /tmp/npm-cache

COPY kargs.d/ /usr/lib/bootc/kargs.d/

COPY . /etc/spaceos/
RUN cp -asf --remove-destination /etc/spaceos/rootfs/. /

RUN set -eux \
    && rsvg-convert \
        --width 465 \
        --height 120 \
        --output /usr/share/plymouth/themes/spinner/watermark.png \
        /usr/share/pixmaps/spaceos-logo.svg

RUN set -eux \
    && KERNEL_VERSION="$(find /usr/lib/modules \
        -mindepth 1 -maxdepth 1 -type d \
        -printf '%f\n' | head -n1)" \
    && env DRACUT_NO_XATTR=1 \
        dracut -vf "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img" "${KERNEL_VERSION}"

RUN fc-cache -f -v

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

RUN systemctl enable greetd.service
RUN systemctl set-default graphical.target

RUN bootc container lint
