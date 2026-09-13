FROM quay.io/fedora/fedora-bootc:44

# =============
# === Wi-Fi ===
# =============
RUN dnf5 install -y \
  linux-firmware \
  'iwl*firmware' \
  NetworkManager-wifi

# ===================
# === DisplayLink ===
# ===================
ADD --checksum=sha256:d29d4786267a12e91da50f1584e595093a6cbdeed2647f301a834d465f5d72c8 \
  https://github.com/displaylink-rpm/displaylink-rpm/releases/download/v6.3.0-1/fedora-44-displaylink-1.15.0-1.github_evdi.x86_64.rpm \
  /tmp/displaylink.rpm

# Safe container build settings.
RUN mkdir -p /etc/dkms/framework.conf.d && \
  printf 'modprobe_on_install="false"\npost_transaction=""\ntry_sign_modules="false"\n' \
  > /etc/dkms/framework.conf.d/bootc.conf

# Package and kernel headers.
RUN kernel_version="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)" && \
  dnf5 install -y --setopt=install_weak_deps=False \
  "kernel-devel-${kernel_version}" \
  /tmp/displaylink.rpm

# EVDI kernel module.
RUN kernel_version="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)" && \
  dkms install evdi/1.15.0-1.github_evdi -k "$kernel_version" && \
  systemctl disable dkms.service && \
  sed -i '/^softdep evdi pre:/d' /etc/modprobe.d/evdi.conf && \
  rm -f /tmp/displaylink.rpm

# ================
# === Packages ===
# ================
RUN dnf5 install -y \
  greetd \
  greetd-selinux \
  tuigreet \
  sway \
  rofi \
  alacritty \
  fish \
  nvim \
  mc \
  git \
  podman \
  firefox 
RUN dnf5 clean all

RUN useradd --defaults --shell /usr/bin/fish

COPY . /etc/spaceos/
RUN cp -asf /etc/spaceos/rootfs/. /

COPY os-release /usr/lib/os-release
RUN ln -sfn ../usr/lib/os-release /etc/os-release

RUN systemctl enable greetd.service
RUN systemctl set-default graphical.target

RUN bootc container lint
