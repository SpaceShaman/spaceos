FROM quay.io/fedora/fedora-bootc:44

ARG DISPLAYLINK_URL=https://github.com/displaylink-rpm/displaylink-rpm/releases/download/v6.3.0-1/fedora-44-displaylink-1.15.0-1.github_evdi.x86_64.rpm
ARG DISPLAYLINK_SHA256=d29d4786267a12e91da50f1584e595093a6cbdeed2647f301a834d465f5d72c8

RUN dnf5 install -y --setopt=install_weak_deps=False \
      curl coreutils dkms kmod make gcc kernel-devel-matched \
    && curl --fail --location --silent --show-error "$DISPLAYLINK_URL" \
      --output /tmp/displaylink.rpm \
    && echo "$DISPLAYLINK_SHA256  /tmp/displaylink.rpm" | sha256sum --check --strict \
    && dnf5 install -y --setopt=install_weak_deps=False /tmp/displaylink.rpm \
    && kernel_version="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)" \
    && dkms install --force "evdi/1.15.0-1.github_evdi" -k "$kernel_version" \
    && depmod -a "$kernel_version" \
    && printf '%s\n' 'options evdi initial_device_count=4' \
      > /etc/modprobe.d/evdi.conf \
    && printf '%s\n' evdi > /etc/modules-load.d/evdi.conf \
    && rm -f /tmp/displaylink.rpm

RUN dnf5 install -y \
  linux-firmware \
  'iwl*firmware' \
  NetworkManager-wifi \
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

RUN useradd --create-home --groups wheel --shell /usr/bin/fish shaman && \
  printf '%s\n' 'shaman:ppp' | chpasswd

COPY kargs.d/ /usr/lib/bootc/kargs.d/

COPY . /etc/spaceos/
RUN cp -asf /etc/spaceos/rootfs/. /

COPY os-release /usr/lib/os-release
RUN ln -sfn ../usr/lib/os-release /etc/os-release
RUN rm -f /etc/system-release && \
  printf 'SpaceOS\n' > /etc/system-release

RUN systemctl enable greetd.service
RUN systemctl set-default graphical.target

RUN bootc container lint
