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
virt-install --name rocky9-lustre-build --memory 4096 --vcpus 2 --cpu host \ 
    --disk path=<path to vms>/rocky9-lustre-build2.qcow2,size=40,format=qcow2 \ 
     --os-variant rocky9 --network bridge=br-lustre,model=virtio --graphics spice \
      --console pty,target_type=serial --cdrom ~/Downloads/Rocky-9.7-x86_64-dvd.iso

```

First step is to install the packages required to build lustre from src, scp it on the VM and run it

```
./install_pkgs.sh
```

A reboot of the VM is required to boot the newer kernel version, then run the lustre build script

```
./build_lustre_script.sh
```

You can use the qcow image you now have a a golden image to create server and client nodes for a lustre
cluster

Create a qcow image for the Lustre target(OST/MDT/MGT)

```
qemu-img create -f raw /var/lib/libvirt/images/mdt1.raw 20G
qemu-img info /var/lib/libvirt/images/mdt1.raw
ls -lh /var/lib/libvirt/images/mdtt1.raw

virsh attach-disk rocky9-lustre-build \
  /var/lib/libvirt/images/ost1.raw \
  vdb \
  --driver qemu \
  --subdriver raw \
  --targetbus virtio \
  --persistent
```

Once that's done, you can attach a drive to the VM and mkfs.lustre with a ldiskfs backend

First the MDS/MGS node
```
mkfs.lustre --mdt --mgs --fsname=lustre1 --index=0 --backfstype=ldiskfs /dev/vdb
```

Then each OSS node

```
 mkfs.lustre   --ost   --mgsnode=<MGS NID>  --backfstype=ldiskfs --fsname=lustre1   --index=2   /dev/vdb
```
