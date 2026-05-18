#!/usr/bin/env bash
set -euo pipefail

ROLE=""
FSNAME="lustrefs"
MGS_NID=""
MDT_DEV=""
OST_DEVS=()
INDEX_BASE=0
MOUNTPOINT="/mnt/lustre"
FORMAT="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) ROLE="$2"; shift 2 ;;
    --fsname) FSNAME="$2"; shift 2 ;;
    --mgs-nid) MGS_NID="$2"; shift 2 ;;
    --mdt-dev) MDT_DEV="$2"; shift 2 ;;
    --ost-dev) OST_DEVS+=("$2"); shift 2 ;;
    --index-base) INDEX_BASE="$2"; shift 2 ;;
    --mountpoint) MOUNTPOINT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

modprobe lnet
modprobe lustre

case "$ROLE" in
  mds)
    [[ -n "$MDT_DEV" ]] || { echo "Missing --mdt-dev"; exit 1; }

    if [[ "$FORMAT" == "true" ]]; then
      mkfs.lustre \
        --fsname="$FSNAME" \
        --mgs \
        --mdt \
        --index=0 \
        "$MDT_DEV"
    fi

    mkdir -p /mnt/mdt0
    mount -t lustre "$MDT_DEV" /mnt/mdt0
    ;;

  oss)
    [[ "${#OST_DEVS[@]}" -gt 0 ]] || { echo "Missing --ost-dev"; exit 1; }
    [[ -n "$MGS_NID" ]] || { echo "Missing --mgs-nid"; exit 1; }

    i=0
    for dev in "${OST_DEVS[@]}"; do
      index=$((INDEX_BASE + i))

      if [[ "$FORMAT" == "true" ]]; then
          if  mkfs.lustre \
              --fsname="$FSNAME" \
              --ost \
              --mgsnode="$MGS_NID" \
              --index="$index" \
              "$dev"; then
            echo "Formatted OST index $index on $dev"
          else
            echo "mkfs.lustre failed or device already formatted; checking existing Lustre label"
            tunefs.lustre --dryrun "$dev"
          fi
      fi

      mkdir -p "/mnt/ost${index}"
      for attempt in {1..12}; do
          if ! mountpoint -q "/mnt/ost${index}"; then
              mount -t lustre "$dev" "/mnt/ost${index}"
              break
          fi
          echo "OST${index} mount failed, retrying in 10s..."
          sleep 10
     done
      i=$((i + 1))
    done
    ;;

  client)
    [[ -n "$MGS_NID" ]] || { echo "Missing --mgs-nid"; exit 1; }

    mkdir -p "$MOUNTPOINT"
    mount -t lustre "${MGS_NID}:/${FSNAME}" "$MOUNTPOINT"
    ;;

  *)
    echo "Invalid or missing --role: $ROLE"
    exit 1
    ;;
esac
