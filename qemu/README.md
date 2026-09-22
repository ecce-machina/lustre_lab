
cd /home/L3/lustre_lab/qemu

IMAGE_DIR=/home/L3/lustre-vms \
BASE_IMAGE=/home/L3/lustre-vms/base.qcow2 \
SSH_KEY=/home/L3/.ssh/lustre_lab \
OSS_COUNT=1 \
CLIENT_COUNT=1 \
./create_cluster.sh

