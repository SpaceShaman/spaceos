FROM quay.io/fedora/fedora-bootc:44

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

RUN systemctl enable greetd.service
RUN systemctl set-default graphical.target

RUN bootc container lint
