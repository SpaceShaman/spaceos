FROM quay.io/fedora/fedora-bootc:44

RUN dnf5 install -y 'dnf5-command(copr)'

RUN dnf5 copr enable -y eddievs/hyprland

# Install Hyprland and related packages
RUN dnf5 install -y \ 
  hyprland \ 
  sddm \ 
  tuned \ 
  tuned-ppd \ 
  kitty \ 
  waybar \ 
  hyprpolkitagent \ 
  nautilus \ 
  pavucontrol \ 
  alsa-sof-firmware \ 
  alsa-utils \ 
  blueman \ 
  NetworkManager-wifi \ 
  iwl* \ 
  nm-connection-editor-desktop \ 
  gvfs \ 
  gvfs-mtp
RUN dnf5 clean all

RUN systemctl enable sddm.service
RUN systemctl set-default graphical.target

COPY skel/ /etc/skel/

RUN bootc container lint
