locals {
  cluster_hosts = join("\n", concat(
    ["10.10.0.10 lustre-mds"],
    [
      for i in range(var.oss_count) :
      "10.10.0.${20 + i} lustre-oss${i + 1}"
    ],
    [
      for i in range(var.client_count) :
      "10.10.0.${30 + i} lustre-client${i + 1}"
    ]
  ))

  configure_cluster_hosts = <<-SCRIPT
    echo '${base64encode(local.cluster_hosts)}' | base64 -d > /tmp/lustre-lab-hosts
    bash /opt/lustre-lab/configure_cluster_hosts.sh /tmp/lustre-lab-hosts
    rm -f /tmp/lustre-lab-hosts
  SCRIPT

  harness_ost_hosts = join(" ", [
    for i in range(var.oss_count) : "lustre-oss${i + 1}"
  ])

  harness_ost_devices = join(" ", [
    for i in range(var.oss_count) : "/dev/disk/by-id/google-ost${i}"
  ])
}
