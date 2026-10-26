#!/bin/bash
set -euo pipefail

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
dnf install -y \
  https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm \
  'dnf-command(config-manager)'
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

dnf config-manager --set-enabled devel-debuginfo
dnf install -y kernel-debuginfo kernel-devel
dnf install -y openmpi-devel

## Lustre test harness dependencies

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
