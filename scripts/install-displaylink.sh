#!/usr/bin/env bash

set -euo pipefail

readonly displaylink_url="https://github.com/displaylink-rpm/displaylink-rpm/releases/download/v6.3.0-1/fedora-44-displaylink-1.15.0-1.github_evdi.x86_64.rpm"
readonly displaylink_sha256="d29d4786267a12e91da50f1584e595093a6cbdeed2647f301a834d465f5d72c8"
readonly displaylink_rpm="/tmp/displaylink.rpm"
readonly evdi_version="1.15.0-1.github_evdi"

curl --fail --location --silent --show-error \
  "$displaylink_url" \
  --output "$displaylink_rpm"
echo "$displaylink_sha256  $displaylink_rpm" | sha256sum --check --strict

mkdir -p /etc/dkms/framework.conf.d
printf 'modprobe_on_install="false"\npost_transaction=""\ntry_sign_modules="false"\n' \
  > /etc/dkms/framework.conf.d/bootc.conf

kernel_version="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)"
dnf5 install -y --setopt=install_weak_deps=False \
  "kernel-devel-${kernel_version}" \
  "$displaylink_rpm"

dkms install "evdi/$evdi_version" -k "$kernel_version"
systemctl disable dkms.service
sed -i '/^softdep evdi pre:/d' /etc/modprobe.d/evdi.conf
rm -f "$displaylink_rpm"
