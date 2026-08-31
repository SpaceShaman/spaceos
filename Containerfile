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
  mc
RUN dnf5 clean all

RUN useradd --defaults --shell /usr/bin/fish

RUN systemctl enable greetd.service
RUN systemctl set-default graphical.target

COPY files/ /

RUN bootc container lint
