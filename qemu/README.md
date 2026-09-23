
# QEMU Lustre Lab

The QEMU backend creates a local Lustre cluster using libvirt/KVM.

## Build the base image

Build the Rocky Linux/Lustre base image with Packer:

```bash
cd packer/qemu
packer init .
packer build \
  -var="ssh_public_key_file=$HOME/.ssh/lustre_lab.pub" \
  .

```

## Create the cluster

```
IMAGE_DIR=/path/to/vm/images \
BASE_IMAGE=/path/to/base.qcow2 \
SSH_KEY=/path/to/private/key \
OSS_COUNT=2 \
CLIENT_COUNT=2 \
./create_cluster.sh

```

### Verify it's all working fine
```
lfs df -h /mnt/lustre
sinfo
srun -N2 -n2 hostname

```

## Destroy the cluster

```
IMAGE_DIR=/path/to/vm/images \
./destroy_cluster.sh
```

