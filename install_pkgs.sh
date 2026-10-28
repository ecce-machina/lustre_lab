#!/bin/bash
set -e

#### virt-install \
 # --name rocky9-lustre-build1 \
  #--name rocky9-lustre-build1 \
  #--memory 4096 \
 # --vcpus 2 \
  #--cpu host \
 # --disk path=/home/doob/vms/rocky9-lustre-build1.qcow2,size=40,format=qcow2 \
 # --os-variant rocky9 \
 # --network bridge=br-lustre,model=virtio \
 # --graphics spice dnf install -y epel-release 'dnf-command(config-manager)'\
 # --console pty,target_type=serial \
 # --cdrom /home/doob/Downloads/Rocky-9.7-x86_64-dvd.iso
## Get required packages and tools

dnf update -y
dnf install -y epel-release 'dnf-command(config-manager)'
dnf config-manager --set-enabled crb
dnf groupinstall -y "Development Tools"
dnf install -y \
  git rpm-build rpmdevtools make autoconf automake libtool pkgconf-pkg-config \
  byacc flex bison patch diffutils which file \
  libuuid-devel lsb_release texinfo libaio-devel swig quilt \
  keyutils keyutils-libs keyutils-libs-devel \
  elfutils-libelf-devel openssl-devel libyaml-devel krb5-devel \
  libmount-devel libblkid-devel libselinux-devel systemd-devel \
  python3-devel perl-ExtUtils-Embed wget curl libnl3 libnl3-devel


# select a kernel with matching runtime, development and debuginfo packages.
dnf config-manager --set-enabled devel-debuginfo

KERNEL_VERSION="${KERNEL_VERSION:-}"

if [[ -z "$KERNEL_VERSION" ]]; then
    # Find the newest version common to kernel-devel and kernel-debuginfo.
    KERNEL_VERSION="$(
        comm -12 \
            <(dnf repoquery --qf '%{version}-%{release}.%{arch}' \
                --arch x86_64 kernel-devel | sort -Vu) \
            <(dnf repoquery --qf '%{version}-%{release}.%{arch}' \
                --arch x86_64 kernel-debuginfo | sort -Vu) \
            | sort -V | tail -1
    )"
fi

if [[ -z "$KERNEL_VERSION" ]]; then
    echo "ERROR: No matching kernel-devel/kernel-debuginfo version"
    exit 1
fi

echo "Selected kernel: $KERNEL_VERSION"

dnf install -y \
    "kernel-core-$KERNEL_VERSION" \
    "kernel-modules-$KERNEL_VERSION" \
    "kernel-devel-$KERNEL_VERSION" \
    "kernel-debuginfo-$KERNEL_VERSION" \
    "kernel-debuginfo-common-x86_64-$KERNEL_VERSION" \
    grubby

test -f "/boot/vmlinuz-$KERNEL_VERSION"
test -d "/usr/src/kernels/$KERNEL_VERSION"

grubby --set-default "/boot/vmlinuz-$KERNEL_VERSION"

echo "Default boot kernel:"
grubby --default-kernel

dnf install -y openmpi-devel


dnf install -y \
  pdsh pdsh-rcmd-ssh \
  openssh-clients \
  rsync expect \
  bc jq \
  lsof psmisc procps-ng \
  iproute iputils \
  e2fsprogs \
  attr acl

## REBOOT REQUIRED HERE
