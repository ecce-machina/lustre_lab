#!/usr/bin/env bash
set -euo pipefail

CONFIG=${CONFIG:-/opt/lustre-lab/harness/cluster.sh}
CLIENT_HOSTS=${CLIENT_HOSTS:-"lustre-client1 lustre-client2"}

(( EUID == 0 )) || {
    echo "Run as root" >&2
    exit 1
}

[[ -r "$CONFIG" ]] || {
    echo "Cannot read $CONFIG" >&2
    exit 1
}

# Read only configuration assignments; do not source local.sh.
get_config() {
    local key=$1
    local value

    value=$(sed -n "s/^${key}=//p" "$CONFIG" | head -n 1)
    [[ -n "$value" ]] || {
        echo "Missing $key in $CONFIG" >&2
        exit 1
    }

    printf '%s\n' "$value"
}

remote_unmount() {
    local host=$1
    local mount=$2

    echo "=== $host: $mount ==="

    ssh -o BatchMode=yes "root@$host" bash -s -- "$mount" <<'REMOTE'
set -euo pipefail
mount=$1

if mountpoint -q "$mount"; then
    umount "$mount"
fi

if mountpoint -q "$mount"; then
    echo "ERROR: $mount is still mounted" >&2
    exit 1
fi
REMOTE
}

verify_node() {
    local host=$1

    if ! ssh -o BatchMode=yes "root@$host" \
        'test -z "$(findmnt -rn -t lustre,lustre_tgt)"'; then
        echo "ERROR: Lustre mounts remain on $host" >&2
        exit 1
    fi
}

# 1. Stop clients while the MGS is available.
for host in $CLIENT_HOSTS; do
    remote_unmount "$host" /mnt/lustre
    remote_unmount "$host" /mnt/lustrefs
    remote_unmount "$host" /mnt/lustrefs2
    verify_node "$host"
done

# 2. Stop OSTs.
ostcount=$(get_config OSTCOUNT)

for ((i=1; i<=ostcount; i++)); do
    host=$(get_config "ost${i}_HOST")
    mount=$(get_config "ost${i}_MOUNT")

    remote_unmount "$host" "$mount"
    verify_node "$host"
done

# 3. Stop MDT/MGS last.
mds_host=$(get_config mds_HOST)
mds_mount=$(get_config mds1_MOUNT)

remote_unmount "$mds_host" "$mds_mount"
verify_node "$mds_host"

echo "Lustre cluster is ready for upstream tests."
