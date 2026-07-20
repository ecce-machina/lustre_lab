#!/usr/bin/env bash
set -euo pipefail

MOUNT=${LUSTRE_MOUNT:-/mnt/lustre}
DURATION=${DURATION:-300}
NODE=${SLURMD_NODENAME:-$(hostname -s)}
FILE="$MOUNT/machina-datasets/read/$NODE/read.dat"

[[ -f "$FILE" ]] || {
    echo "Read dataset missing on $NODE: $FILE" >&2
    echo "Run: lustre-workload run prepare-read --size <size>" >&2
    exit 1
}

exec fio \
    --name=read-heavy \
    --filename="$FILE" \
    --rw=read \
    --bs=1M \
    --direct=1 \
    --iodepth=32 \
    --time_based=1 \
    --runtime="$DURATION" \
    --group_reporting
