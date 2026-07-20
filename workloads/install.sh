#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
INSTALL_ROOT=/opt/lustre-lab/workloads

install -d -m 0755 "$INSTALL_ROOT/scripts"
install -m 0755 "$SOURCE_DIR/lustre-workload" /usr/local/bin/lustre-workload
install -m 0755 "$SOURCE_DIR/workload.sbatch" "$INSTALL_ROOT/workload.sbatch"

for script in "$SOURCE_DIR"/scripts/*.sh; do
    install -m 0755 "$script" "$INSTALL_ROOT/scripts/$(basename "$script")"
done

echo "Installed Lustre workloads on $(hostname -s)"
