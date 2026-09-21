for vm in lustre-client1 lustre-oss1 lustre-mds; do
    virsh destroy "$vm" 2>/dev/null || true
    virsh undefine "$vm" 2>/dev/null || true
done

virsh list --all
