
#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-lustre-lab}"
IMAGE_DIR="${IMAGE_DIR:-/home/libvirt/images/${CLUSTER_NAME}}"
NETWORK_NAME="${NETWORK_NAME:-${CLUSTER_NAME}-net}"

[[ $EUID -eq 0 ]] || {
    echo "ERROR: run as root" >&2
    exit 1
}

# Never delete the shared image directory or an arbitrary path.
IMAGE_DIR="$(realpath -m -- "$IMAGE_DIR")"
case "$IMAGE_DIR" in
    /home/libvirt/images/*) ;;
    *)
        echo "ERROR: unsafe IMAGE_DIR: $IMAGE_DIR" >&2
        exit 1
        ;;
esac

# Only VMs belonging to this cluster.
for vm in "${CLUSTER_NAME}-mds"; do
    if virsh -c qemu:///system dominfo "$vm" &>/dev/null; then
        virsh -c qemu:///system destroy "$vm" 2>/dev/null || true
        virsh -c qemu:///system undefine "$vm"
    fi
done

for vm in $(virsh -c qemu:///system list --all --name); do
    case "$vm" in
        "${CLUSTER_NAME}-oss"[0-9]*|"${CLUSTER_NAME}-client"[0-9]*)
            virsh -c qemu:///system destroy "$vm" 2>/dev/null || true
            virsh -c qemu:///system undefine "$vm"
            ;;
    esac
done

# Remove the cluster's network.
if virsh -c qemu:///system net-info "$NETWORK_NAME" &>/dev/null; then
    virsh -c qemu:///system net-destroy "$NETWORK_NAME" 2>/dev/null || true
    virsh -c qemu:///system net-undefine "$NETWORK_NAME"
fi

# Remove only this cluster's image directory.
if [[ -d "$IMAGE_DIR" ]]; then
    rm -rf -- "$IMAGE_DIR"
fi

echo "Cluster ${CLUSTER_NAME} destroyed."

