FROM quay.io/fedora/fedora-bootc:44

# Install Hyprland and related packages
RUN dnf5 install 'dnf5-command(copr)'
RUN dnf copr enable -y solopasha/hyprland
RUN dnf install -y hyprland sddm tuned tuned-ppd kitty waybar hyprpolkitagent nautilus pavucontrol alsa-sof-firmware alsa-utils blueman NetworkManager-wifi iwl* nm-connection-editor-desktop gvfs gvfs-mtp
RUN systemctl enable sddm.service
RUN systemctl set-default graphical.target

COPY skel/ /etc/skel/

RUN bootc container lint
