#!/bin/bash
set -euo pipefail

# Disable the default Rocky repositories.
# Keep their configuration files for reference.
for repo in /etc/yum.repos.d/rocky*.repo /etc/yum.repos.d/Rocky*.repo; do
    [ -f "$repo" ] || continue
    sed -i 's/^enabled=1/enabled=0/' "$repo"
done

# Configure version-specific repositories.
cat > /etc/yum.repos.d/lustre-lab-rocky97.repo <<'EOF'
[lab-baseos]
name=Rocky 9.7 BaseOS
baseurl=https://dl.rockylinux.org/vault/rocky/9.7/BaseOS/$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9

[lab-appstream]
name=Rocky 9.7 AppStream
baseurl=https://dl.rockylinux.org/vault/rocky/9.7/AppStream/$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9

[lab-crb]
name=Rocky 9.7 CRB
baseurl=https://dl.rockylinux.org/vault/rocky/9.7/CRB/$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9
EOF

dnf clean all
dnf makecache
