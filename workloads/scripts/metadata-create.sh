#!/usr/bin/env bash
set -euo pipefail

MOUNT=${LUSTRE_MOUNT:-/mnt/lustre}
COUNT=${COUNT:-50000}
PARALLEL=${PARALLEL:-16}
NODE=${SLURMD_NODENAME:-$(hostname -s)}
TARGET="$MOUNT/machina-datasets/metadata/$NODE"

rm -rf "$TARGET"
mkdir -p "$TARGET"

export TARGET
seq 1 "$COUNT" |
    xargs -P "$PARALLEL" -n 1 bash -c '
        n=$1
        dir="$TARGET/dir-$((n / 1000))"
        mkdir -p "$dir"
        : > "$dir/file-$n"
    ' _

echo "created=$COUNT node=$NODE target=$TARGET"
