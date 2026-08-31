FROM quay.io/fedora/fedora-bootc:44

RUN dnf5 install -y 'dnf5-command(copr)'

RUN dnf5 copr enable -y eddievs/hyprland

# Install Hyprland and related packages
RUN dnf5 install -y \
  --setopt=exclude_from_weak='kitty*' \
  sway \
  rofi \
  alacritty \
  fish \
  nvim \
  mc
RUN dnf5 clean all

RUN useradd --defaults --shell /usr/bin/fish

RUN systemctl enable getty@tty1.service
RUN systemctl set-default multi-user.target

COPY files/ /


RUN bootc container lint
