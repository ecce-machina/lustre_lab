# lustre_helpers

### Collection of scripts to quickly spin up a lustre clusters using qemu or aws

You need to create a bridge on the host server

```
# create the bridge
ip link add name br-lustre type bridge

# bring it up
ip link set br-lustre up

# (optional) give it an IP for host-side access
ip addr add 192.168.100.1/24 dev br-lustre

```

Then you create a VM with the Rocky ISO

```
virt-install --name rocky9-lustre-build2 --memory 4096 --vcpus 2 --cpu host \ 
    --disk path=/home/doob/vms/rocky9-lustre-build2.qcow2,size=40,format=qcow2 \ 
     --os-variant rocky9 --network bridge=br-lustre,model=virtio --graphics spice \
      --console pty,target_type=serial --cdrom /home/doob/Downloads/Rocky-9.7-x86_64-dvd.iso

```

First step is to install the packages required to build lustre from src, scp it on the VM and run it

```
./install_pkgs.sh
```

A reboot of the VM is required to boot the newer kernel version, then run the lustre build script

```
./build_lustre_script.sh
```

At the end, you can attach a drive to the VM and mkfs.lustre with a ldiskfs backend

```
mkfs.lustre   --ost   --mgsnode=192.168.100.100@tcp  --backfstype=ldiskfs --fsname=lustre1   --index=2   /dev/vdb

```
