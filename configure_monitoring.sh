#!/usr/bin/env bash
set -euxo pipefail

# for debug
exec > >(tee -a /var/log/configure_monitoring.log)
exec 2>&1

MDS_IP=""
OSS_IPS=""
CLIENT_IPS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mds-ip)
      MDS_IP="$2"
      shift 2
      ;;
    --oss-ips)
      OSS_IPS="$2"
      shift 2
      ;;
    --client-ips)
      CLIENT_IPS="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

PROM_VERSION="2.53.0"

dnf install -y curl tar firewalld

systemctl enable --now firewalld || true
firewall-cmd --permanent --add-port=9090/tcp || true
firewall-cmd --permanent --add-port=3000/tcp || true
firewall-cmd --reload || true

useradd --no-create-home --shell /sbin/nologin prometheus || true

cd /tmp
curl -LO "https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz"
tar xzf "prometheus-${PROM_VERSION}.linux-amd64.tar.gz"

install -m 0755 "prometheus-${PROM_VERSION}.linux-amd64/prometheus" /usr/local/bin/prometheus
install -m 0755 "prometheus-${PROM_VERSION}.linux-amd64/promtool" /usr/local/bin/promtool

mkdir -p /etc/prometheus /var/lib/prometheus
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

cat >/etc/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "monitoring"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "lustre_nodes"
    static_configs:
      - targets:
EOF

for ip in "$MDS_IP"; do
  echo "          - \"$ip:9100\"" >> /etc/prometheus/prometheus.yml
done

IFS=',' read -ra OSS_ARRAY <<< "$OSS_IPS"
for ip in "${OSS_ARRAY[@]}"; do
  [[ -n "$ip" ]] && echo "          - \"$ip:9100\"" >> /etc/prometheus/prometheus.yml
done

IFS=',' read -ra CLIENT_ARRAY <<< "$CLIENT_IPS"
for ip in "${CLIENT_ARRAY[@]}"; do
  [[ -n "$ip" ]] && echo "          - \"$ip:9100\"" >> /etc/prometheus/prometheus.yml
done

chown prometheus:prometheus /etc/prometheus/prometheus.yml

cat >/etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
After=network-online.target
Wants=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus \\
  --web.listen-address=0.0.0.0:9090

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now prometheus

cat >/etc/yum.repos.d/grafana.repo <<EOF
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

dnf install -y grafana

mkdir -p /etc/grafana/provisioning/datasources

cat >/etc/grafana/provisioning/datasources/prometheus.yml <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
EOF

systemctl enable --now grafana-server
systemctl restart grafana-server
