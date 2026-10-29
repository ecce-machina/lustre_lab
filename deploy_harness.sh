#!/usr/bin/env bash
set -euo pipefail

CONFIG=${CONFIG:-/opt/lustre-lab/harness/cluster.sh}
MDS_HOST=${MDS_HOST:-lustre-mds}
OST_HOSTS=${OST_HOSTS:?Set OST_HOSTS}

for host in "$MDS_HOST" $OST_HOSTS; do
    for attempt in {1..12}; do
        if ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" \
            'mkdir -p /opt/lustre-lab/harness' &&
           scp -o BatchMode=yes -o ConnectTimeout=5 "$CONFIG" "$host:$CONFIG"; then
            echo "Deployed harness configuration to $host"
            break
        fi

        if (( attempt == 12 )); then
            echo "Failed to deploy harness configuration to $host" >&2
            exit 1
        fi

        sleep 10
    done
done
