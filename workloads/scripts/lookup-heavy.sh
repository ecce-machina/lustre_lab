#!/usr/bin/env bash
set -euo pipefail

MOUNT=${LUSTRE_MOUNT:-/mnt/lustre}
DURATION=${DURATION:-300}
PARALLEL=${PARALLEL:-16}
NODE=${SLURMD_NODENAME:-$(hostname -s)}
TARGET="$MOUNT/machina-datasets/metadata/$NODE"

[[ -d "$TARGET" ]] || {
    echo "Metadata dataset missing on $NODE: $TARGET" >&2
    echo "Run: lustre-workload run metadata-create --count <count>" >&2
    exit 1
}

deadline=$((SECONDS + DURATION))
passes=0

while ((SECONDS < deadline)); do
    find "$TARGET" -type f -print0 |
        xargs -0 -r -P "$PARALLEL" stat -- >/dev/null
    ((passes += 1))
done

echo "lookup_passes=$passes node=$NODE target=$TARGET"
