#!/usr/bin/env bash
set -euo pipefail

MOUNT=${LUSTRE_MOUNT:-/mnt/lustre}
SIZE=${SIZE:-8G}
DURATION=${DURATION:-300}
NODE=${SLURMD_NODENAME:-$(hostname -s)}
RUN_ID=${SLURM_JOB_ID:-manual}
TARGET="$MOUNT/machina-workloads/$RUN_ID/$NODE"

mkdir -p "$TARGET"

exec fio \
    --name=write-heavy \
    --filename="$TARGET/write.dat" \
    --rw=write \
    --bs=1M \
    --size="$SIZE" \
    --direct=1 \
    --iodepth=32 \
    --time_based=1 \
    --runtime="$DURATION" \
    --group_reporting
