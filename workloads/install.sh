#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
INSTALL_DIR=/opt/lustre-workloads

install -d -m 0755 "$INSTALL_DIR"
install -d -m 0755 "$INSTALL_DIR/scripts"

install -m 0755 \
    "$SOURCE_DIR/lustre-workload.sh" \
    "$INSTALL_DIR/lustre-workload.sh"

install -m 0644 \
    "$SOURCE_DIR/workload.sbatch" \
    "$INSTALL_DIR/workload.sbatch"

install -m 0755 \
    "$SOURCE_DIR"/scripts/*.sh \
    "$INSTALL_DIR/scripts/"

ln -sfn \
    "$INSTALL_DIR/lustre-workload.sh" \
    /usr/local/bin/lustre-workload.sh

echo "Installed Lustre workloads on $(hostname -s)"
