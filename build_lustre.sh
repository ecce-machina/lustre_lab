## Install e2fsprogs with the whamcloud patch for ldiskfs

echo "Downloading and installing e2fsprogs with whamcloud patch"

wget -r -np -nd -A "*.rpm" https://downloads.whamcloud.com/public/e2fsprogs/latest/el9/RPMS/x86_64/
dnf install -y ./*.rpm


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

## point to the e2fs rpm build

./configure --enable-server --enable-ldiskfs   
make
make install 
depmod -a
modprobe -D lustre
modprobe ldiskfs

