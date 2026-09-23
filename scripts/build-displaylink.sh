#!/usr/bin/bash
set -euxo pipefail

fedora_version=${1:?Usage: build-displaylink.sh FEDORA_VERSION SIGNING_KEY_ID}
signing_key_id=${2:?Usage: build-displaylink.sh FEDORA_VERSION SIGNING_KEY_ID}

if [[ ! "$fedora_version" =~ ^[0-9]+$ ]]; then
    printf 'FEDORA_VERSION must be a number.\n' >&2
    exit 2
fi

if [[ ! "$signing_key_id" =~ ^[[:xdigit:]]{8}$ ]]; then
    printf 'SIGNING_KEY_ID must contain exactly 8 hexadecimal characters.\n' >&2
    exit 2
fi

signing_key_id=${signing_key_id,,}
kernel_version=$(find /usr/lib/modules \
    -mindepth 1 -maxdepth 1 -type d \
    -printf '%f\n' | head -n1)

printf 'Building EVDI for kernel: %s\n' "$kernel_version"

# A bootc image is immutable while Fedora's DNF repositories move forward.
# Koji retains the development RPMs matching the image kernel after that kernel
# has been superseded in the live repositories, keeping local and CI builds stable.
dnf5 -y install curl

kernel_package_version=${kernel_version%%-*}
kernel_release=${kernel_version#*-}
kernel_arch=${kernel_version##*.}
kernel_release=${kernel_release%.*}

rpm --import "/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-${fedora_version}-primary"

for package in kernel-devel kernel-devel-matched; do
    rpm_path="/tmp/${package}.rpm"
    curl \
        --fail \
        --location \
        --retry 5 \
        --retry-all-errors \
        --output "$rpm_path" \
        "https://kojipkgs.fedoraproject.org/packages/kernel/${kernel_package_version}/${kernel_release}/data/signed/${signing_key_id}/${kernel_arch}/${package}-${kernel_version}.rpm"

    rpmkeys --checksig "$rpm_path" | grep -F 'digests signatures OK'
    test "$(rpm -qp --queryformat '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}' "$rpm_path")" = \
        "${package}-${kernel_version}"
done

dnf5 -y install \
    akmods \
    gcc \
    gcc-c++ \
    make \
    dnf5-plugins \
    /tmp/kernel-devel.rpm \
    /tmp/kernel-devel-matched.rpm

rm -f /tmp/kernel-devel.rpm /tmp/kernel-devel-matched.rpm

dnf5 -y install \
    kmod-evdi \
    akmod-evdi

# UBlue explicitly uses these flags for EVDI.
export CFLAGS="-fno-pie -no-pie"
akmods \
    --force \
    --kernels "$kernel_version" \
    --kmod evdi

# Fail the image build if EVDI was not actually produced.
modinfo "/usr/lib/modules/${kernel_version}/extra/evdi/evdi.ko.xz"

# Keep only the resulting binary kmod RPM.
mkdir -p /out/kmod
find /var/cache/akmods/evdi \
    -type f \
    -name '*.rpm' \
    -exec cp -v -t /out/kmod/ {} +

# Download the userspace part of DisplayLink.
mkdir -p /out/userspace
dnf5 download \
    --destdir=/out/userspace \
    libevdi \
    displaylink

find /out -type f -print
