#!/usr/bin/env bash
set -euo pipefail

MOUNT=${LUSTRE_MOUNT:-/mnt/lustre}
SIZE=${SIZE:-8G}
NODE=${SLURMD_NODENAME:-$(hostname -s)}
TARGET="$MOUNT/machina-datasets/read/$NODE"
FILE="$TARGET/read.dat"

mkdir -p "$TARGET"

exec fio \
    --name=prepare-read \
    --filename="$FILE" \
    --rw=write \
    --bs=1M \
    --size="$SIZE" \
    --direct=1 \
    --iodepth=16 \
    --end_fsync=1 \
    --group_reporting
