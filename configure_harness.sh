#!/usr/bin/env bash
set -euo pipefail

FSNAME=${FSNAME:-lustrefs}
MGSNID=${MGSNID:-10.10.0.10@tcp}
MDS_HOST=${MDS_HOST:-lustre-mds}
MDS_DEV=${MDS_DEV:?Set MDS_DEV}
OUTPUT=${OUTPUT:-/opt/lustre-lab/harness/cluster.sh}
STOCK_CONFIG=/usr/lib64/lustre/tests/cfg/local.sh

OST_HOSTS=${OST_HOSTS:?Set OST_HOSTS}
OST_DEVICES=${OST_DEVICES:?Set OST_DEVICES}

read -r -a ost_hosts <<< "$OST_HOSTS"
read -r -a ost_devices <<< "$OST_DEVICES"

OSTCOUNT=${#ost_hosts[@]}

if (( OSTCOUNT == 0 || OSTCOUNT != ${#ost_devices[@]} )); then
    echo "Error: OST hosts and devices must have matching nonzero counts" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"

cat > "$OUTPUT" <<CONFIG
# Generated Lustre test configuration
FSNAME=$FSNAME
MDSCOUNT=1
OSTCOUNT=$OSTCOUNT

mds_HOST=$MDS_HOST
mgs_HOST=$MDS_HOST
MDSDEV1=$MDS_DEV
mds1_MOUNT=/mnt/mdt0
CONFIG

for ((i=0; i<OSTCOUNT; i++)); do
    printf 'ost%d_HOST=%q\n' "$((i+1))" "${ost_hosts[i]}" >> "$OUTPUT"
    printf 'OSTDEV%d=%q\n' "$((i+1))" "${ost_devices[i]}" >> "$OUTPUT"
    printf 'ost%d_MOUNT=/mnt/ost%d\n' "$((i+1))" "$i" >> "$OUTPUT"
done

cat >> "$OUTPUT" <<CONFIG

MGSNID=$MGSNID
PDSH="pdsh -S -Rssh -w"

RUNAS_ID=1000
RUNAS_GID=1005

. $STOCK_CONFIG
CONFIG

echo "Generated $OUTPUT"
