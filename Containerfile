FROM quay.io/fedora/fedora-bootc:44

RUN dnf5 install -y 'dnf5-command(copr)'

RUN dnf5 copr enable -y eddievs/hyprland

# Install Hyprland and related packages
RUN dnf5 install -y \
  hyprland \
  sddm \
  waybar \
  alacritty \
  fish \
  nvim
RUN dnf5 clean all

RUN systemctl enable sddm.service
RUN systemctl set-default graphical.target

COPY skel/ /etc/skel/

RUN bootc container lint
