#!/usr/bin/env bash
#SBATCH --time=01:00:00
#SBATCH --output=/mnt/lustre/machina-workloads/logs/%x-%j.out
#SBATCH --error=/mnt/lustre/machina-workloads/logs/%x-%j.err

set -euo pipefail

: "${WORKLOAD:?WORKLOAD is required}"
WORKLOAD_ROOT=${WORKLOAD_ROOT:-/opt/lustre-lab/workloads}
SCRIPT="$WORKLOAD_ROOT/scripts/$WORKLOAD.sh"

[[ -x "$SCRIPT" ]] || {
    echo "Workload script is missing or not executable: $SCRIPT" >&2
    exit 1
}

mkdir -p /mnt/lustre/machina-workloads/logs

echo "job_id=$SLURM_JOB_ID"
echo "workload=$WORKLOAD"
echo "nodes=$SLURM_JOB_NODELIST"
echo "started_at=$(date -u --iso-8601=seconds)"

srun \
    --nodes="$SLURM_JOB_NUM_NODES" \
    --ntasks="$SLURM_NTASKS" \
    --ntasks-per-node=1 \
    "$SCRIPT"

echo "finished_at=$(date -u --iso-8601=seconds)"
