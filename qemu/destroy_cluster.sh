#1/bin/bash
set -euo pipefail

for vm in lustre-client1 lustre-oss1 lustre-mds; do
    virsh destroy "$vm" 2>/dev/null || true
    virsh undefine "$vm" 2>/dev/null || true
done

echo "No lustre lab VMs should be in the following list"
virsh list --all

rm -f \
    "$IMAGE_DIR"/lustre-mds.qcow2 \
    "$IMAGE_DIR"/lustre-oss*.qcow2 \
    "$IMAGE_DIR"/lustre-client*.qcow2 \
    "$IMAGE_DIR"/mdt*.raw \
    "$IMAGE_DIR"/ost*.raw

echo "Lustre lab destroyed."



