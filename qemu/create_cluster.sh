#!/usr/bin/env bash
set -euo pipefail

OSS_COUNT="${OSS_COUNT:-2}"
CLIENT_COUNT="${CLIENT_COUNT:-2}"

IMAGE_DIR="${IMAGE_DIR:-/var/lib/libvirt/images/lustre-lab}"
BASE_IMAGE="${BASE_IMAGE:-${IMAGE_DIR}/base.qcow2}"

NETWORK_NAME="${NETWORK_NAME:-lustre-net}"
NETWORK_CIDR="${NETWORK_CIDR:-192.168.150.0/24}"
NETWORK_GATEWAY="${NETWORK_GATEWAY:-192.168.150.1}"

MDS_IP="${MDS_IP:-192.168.150.10}"

VM_MEMORY="${VM_MEMORY:-4096}"
VM_VCPUS="${VM_VCPUS:-2}"

MDT_SIZE="${MDT_SIZE:-20G}"
OST_SIZE="${OST_SIZE:-50G}"

SSH_USER="${SSH_USER:-packer}"
SSH_KEY="${SSH_KEY:-}"
[[ -n "$SSH_KEY" ]] || {
    echo "SSH_KEY must be set (e.g. SSH_KEY=/home/L3/.ssh/lustre_lab)"
    exit 1
}

[[ -f "$SSH_KEY" ]] || {
    echo "SSH private key not found: $SSH_KEY"
    exit 1
}


die() {
    echo "ERROR: $*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

wait_for_ssh() {
    local ip="$1"

    echo "Waiting for SSH on ${ip}..."

    for _ in $(seq 1 60); do
        if ssh \
            -i "$SSH_KEY" \
            -o IdentitiesOnly=yes \
            -o BatchMode=yes \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout=2 \
            "${SSH_USER}@${ip}" true 2>/dev/null; then
            return 0
        fi

        sleep 2
    done

    die "SSH did not become available on ${ip}"
}

create_overlay() {
    local name="$1"
    local path="${IMAGE_DIR}/${name}.qcow2"

    [[ -e "$path" ]] && return 0

    qemu-img create \
        -f qcow2 \
        -F qcow2 \
        -b "$BASE_IMAGE" \
        "$path"
}

create_raw_disk() {
    local path="$1"
    local size="$2"

    [[ -e "$path" ]] && return 0

    qemu-img create -f raw "$path" "$size"
}

require_cmd virsh
require_cmd virt-install
require_cmd qemu-img
require_cmd ssh

[[ $EUID -eq 0 ]] || die "run as root"
[[ -f "$BASE_IMAGE" ]] || die "base image not found: $BASE_IMAGE"

mkdir -p "$IMAGE_DIR"

#
# Network
#

if ! virsh net-info "$NETWORK_NAME" >/dev/null 2>&1; then
    cat >/tmp/lustre-net.xml <<EOF
<network>
  <name>${NETWORK_NAME}</name>
  <forward mode='nat'/>
  <bridge name='virbr-lustre' stp='on' delay='0'/>
  <ip address='${NETWORK_GATEWAY}' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.150.100' end='192.168.150.200'/>
    </dhcp>
  </ip>
</network>
EOF

    virsh net-define /tmp/lustre-net.xml
    virsh net-autostart "$NETWORK_NAME"
fi

NETWORK_ACTIVE="$(
    virsh net-info "$NETWORK_NAME" |
        awk '$1 == "Active:" {print $2}'
)"

if [[ "$NETWORK_ACTIVE" != "yes" ]]; then
    virsh net-start "$NETWORK_NAME"
fi
#
# MDS
#

create_overlay lustre-mds
create_raw_disk "${IMAGE_DIR}/mdt0.raw" "$MDT_SIZE"

virsh net-update "$NETWORK_NAME" add ip-dhcp-host \
    "<host mac='52:54:00:10:00:10' name='lustre-mds' ip='${MDS_IP}'/>" \
    --live --config 2>/dev/null || true

if ! virsh dominfo lustre-mds >/dev/null 2>&1; then
    virt-install \
        --name lustre-mds \
        --memory "$VM_MEMORY" \
        --vcpus "$VM_VCPUS" \
        --cpu host-model \
        --os-variant rocky9 \
        --import \
        --disk path="${IMAGE_DIR}/lustre-mds.qcow2",format=qcow2,bus=virtio \
        --disk path="${IMAGE_DIR}/mdt0.raw",format=raw,bus=virtio \
        --network network="${NETWORK_NAME}",model=virtio,mac=52:54:00:10:00:10 \
        --graphics none \
        --noautoconsole
fi

wait_for_ssh "$MDS_IP"

ssh \
    -i "$SSH_KEY" \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "${SSH_USER}@${MDS_IP}" \
    "sudo /opt/lustre-helpers/configure_lustre_role.sh \
        --role mds \
        --fsname lustrefs \
        --mdt-dev /dev/vdb \
        --format true"

#
# OSS nodes
#

for i in $(seq 0 $((OSS_COUNT - 1))); do
    num=$((i + 1))
    ip="192.168.150.$((20 + i))"
    mac=$(printf '52:54:00:10:00:%02x' $((20 + i)))

    create_overlay "lustre-oss${num}"
    create_raw_disk "${IMAGE_DIR}/ost${i}.raw" "$OST_SIZE"

    virsh net-update "$NETWORK_NAME" add ip-dhcp-host \
        "<host mac='${mac}' name='lustre-oss${num}' ip='${ip}'/>" \
        --live --config 2>/dev/null || true

    if ! virsh dominfo "lustre-oss${num}" >/dev/null 2>&1; then
        virt-install \
            --name "lustre-oss${num}" \
            --memory "$VM_MEMORY" \
            --vcpus "$VM_VCPUS" \
            --cpu host-model \
            --os-variant rocky9 \
            --import \
            --disk path="${IMAGE_DIR}/lustre-oss${num}.qcow2",format=qcow2,bus=virtio \
            --disk path="${IMAGE_DIR}/ost${i}.raw",format=raw,bus=virtio \
            --network network="${NETWORK_NAME}",model=virtio,mac="${mac}" \
            --graphics none \
            --noautoconsole
    fi

    wait_for_ssh "$ip"

    ssh \
        -i "$SSH_KEY" \
        -o IdentitiesOnly=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "${SSH_USER}@${ip}" \
        "sudo /opt/lustre-helpers/configure_lustre_role.sh \
            --role oss \
            --fsname lustrefs \
            --mgs-nid ${MDS_IP}@tcp \
            --ost-dev /dev/vdb \
            --index-base ${i} \
            --format true"
done

#
# Clients
#

for i in $(seq 0 $((CLIENT_COUNT - 1))); do
    num=$((i + 1))
    ip="192.168.150.$((30 + i))"
    mac=$(printf '52:54:00:10:00:%02x' $((30 + i)))

    create_overlay "lustre-client${num}"

    virsh net-update "$NETWORK_NAME" add ip-dhcp-host \
        "<host mac='${mac}' name='lustre-client${num}' ip='${ip}'/>" \
        --live --config 2>/dev/null || true

    if ! virsh dominfo "lustre-client${num}" >/dev/null 2>&1; then
        virt-install \
            --name "lustre-client${num}" \
            --memory "$VM_MEMORY" \
            --vcpus "$VM_VCPUS" \
            --cpu host-model \
            --os-variant rocky9 \
            --import \
            --disk path="${IMAGE_DIR}/lustre-client${num}.qcow2",format=qcow2,bus=virtio \
            --network network="${NETWORK_NAME}",model=virtio,mac="${mac}" \
            --graphics none \
            --noautoconsole
    fi

    wait_for_ssh "$ip"

    ssh \
        -i "$SSH_KEY" \
        -o IdentitiesOnly=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "${SSH_USER}@${ip}" \
        "sudo /opt/lustre-helpers/configure_lustre_role.sh \
            --role client \
            --fsname lustrefs \
            --mgs-nid ${MDS_IP}@tcp \
            --mountpoint /mnt/lustre"
done

# Configure Slurm across Lustre clients.
MUNGE_KEY="$(openssl rand -base64 32)"
CLIENT_RANGE="$(seq -s, -f 'lustre-client%.0f' 1 "$CLIENT_COUNT")"
CONTROLLER_HOST="lustre-client1"

for i in $(seq 0 $((CLIENT_COUNT - 1))); do
    num=$((i + 1))
    ip="192.168.150.$((30 + i))"

    if [[ "$num" -eq 1 ]]; then
        role="controller"
    else
        role="compute"
    fi

    ssh \
        -i "$SSH_KEY" \
        -o IdentitiesOnly=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "${SSH_USER}@${ip}" \
        "sudo /opt/lustre-helpers/configure_slurm_client.sh \
            --role ${role} \
            --node-name lustre-client${num} \
            --client-range '${CLIENT_RANGE}' \
            --cpu-per-client ${VM_VCPUS} \
            --controller-host ${CONTROLLER_HOST} \
            --munge-key '${MUNGE_KEY}'"
done

echo
echo "Lustre lab created:"
echo "  MDS: ${MDS_IP}"

for i in $(seq 0 $((OSS_COUNT - 1))); do
    echo "  OSS$((i + 1)): 192.168.150.$((20 + i))"
done

for i in $(seq 0 $((CLIENT_COUNT - 1))); do
    echo "  Client$((i + 1)): 192.168.150.$((30 + i))"
done

