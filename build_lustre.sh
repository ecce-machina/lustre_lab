#!/usr/bin/env bash
set -euo pipefail

METHOD="source"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --method) METHOD="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

## Install e2fsprogs with the whamcloud patch for ldiskfs

echo "Downloading and installing e2fsprogs with whamcloud patch"

wget -r -np -nd -A "*.rpm" https://downloads.whamcloud.com/public/e2fsprogs/latest/el9/RPMS/x86_64/
sudo dnf -y install *.rpm

install_from_source() {
    echo "Installing kernel sources"

    ## Download kernel sources 
    dnf download --source kernel-$(uname -r)
    rpm -ihv kernel*rpm
    cd ~/rpmbuild/SOURCES
    ## FIXME using uname -r
    tar -xf linux*tar.xz
    KVER=$(uname -r)
    KVER_NOARCH=${KVER%.*}

    cp /boot/config-"$KVER" "$HOME/rpmbuild/SOURCES/linux-$KVER_NOARCH/.config"


    ## Lustre build and install

    echo "Building and setting up lustre "

    cd 
    git clone https://github.com/lustre/lustre-release.git
    cd lustre-release/
    ./autogen.sh

    ./configure --enable-server --enable-ldiskfs   
    make
    make install 
}

install_from_rpms() {
  echo "Installing Lustre server RPMs"

  dnf -y install wget

  mkdir -p /tmp/lustre-rpms
  cd /tmp/lustre-rpms

  wget -r -np -nd -A "*.rpm" \
    https://downloads.whamcloud.com/public/lustre/lustre-2.17.0/el9.7/server/RPMS/x86_64/

  sudo dnf -y install \
  ./kernel-5.14.0-611.13.1_lustre.el9.x86_64.rpm \
  ./kernel-core-5.14.0-611.13.1_lustre.el9.x86_64.rpm \
  ./kernel-modules-5.14.0-611.13.1_lustre.el9.x86_64.rpm \
  ./kernel-modules-core-5.14.0-611.13.1_lustre.el9.x86_64.rpm \
  ./kernel-modules-extra-5.14.0-611.13.1_lustre.el9.x86_64.rpm \
  ./kmod-lustre-2.17.0-1.el9.x86_64.rpm \
  ./kmod-lustre-osd-ldiskfs-2.17.0-1.el9.x86_64.rpm \
  ./lustre-2.17.0-1.el9.x86_64.rpm \
  ./lustre-osd-ldiskfs-mount-2.17.0-1.el9.x86_64.rpm \
  ./lustre-iokit-2.17.0-1.el9.x86_64.rpm \
  ./lustre-tests-2.17.0-1.el9.x86_64.rpm
}

post_install() {
  depmod -a
  modprobe -D lustre
  modprobe ldiskfs
  echo "Installed Lustre RPMs:"
  rpm -qa | grep -i lustre | sort

  echo "Checking module visibility:"
  modprobe -D lustre || true
  modprobe -D ldiskfs || true
  modprobe -D osd-ldiskfs || true
}

case "$METHOD" in
    source)
        install_from_source
        ;;
    rpm)
        install_from_rpms
        ;;
    *)
        echo "Invalid method: $METHOD"
        exit 1
        ;;
esac

post_install
