FROM quay.io/fedora/fedora-bootc:44

RUN --mount=type=bind,source=scripts/install-displaylink.sh,target=/install-displaylink.sh,ro \
  /install-displaylink.sh

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

RUN useradd --defaults --shell /usr/bin/fish

COPY . /etc/spaceos/
RUN cp -asf /etc/spaceos/rootfs/. /

COPY os-release /usr/lib/os-release
RUN ln -sfn ../usr/lib/os-release /etc/os-release
RUN rm -f /etc/system-release && \
  printf 'SpaceOS\n' > /etc/system-release

RUN systemctl enable greetd.service
RUN systemctl set-default graphical.target

RUN bootc container lint
