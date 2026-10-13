#!/usr/bin/env bash
set -euo pipefail

HOSTS_FILE=${HOSTS_FILE:-/etc/hosts}
BEGIN_MARKER="# BEGIN LUSTRE LAB HOSTS"
END_MARKER="# END LUSTRE LAB HOSTS"

if (( $# != 1 )); then
    echo "Usage: $0 <hosts-file>" >&2
    exit 1
fi

INPUT=$1

[[ -f "$INPUT" ]] || {
    echo "Host inventory not found: $INPUT" >&2
    exit 1
}

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

sed "/^${BEGIN_MARKER}$/,/^${END_MARKER}$/d" "$HOSTS_FILE" > "$tmp"

{
    cat "$tmp"
    echo "$BEGIN_MARKER"
    cat "$INPUT"
    echo "$END_MARKER"
} > "${tmp}.new"

cat "${tmp}.new" > "$HOSTS_FILE"
rm -f "${tmp}.new"
