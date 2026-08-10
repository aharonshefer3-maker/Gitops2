#!/bin/bash
# Enable immediate exit on script failure
set -e

# Update package repositories and install system utilities
apt-get update -y
apt-get install -y unzip curl wget

# --- Install K3s Service ---
curl -sfL https://get.k3s.io | sh -s -
systemctl daemon-reload
systemctl enable --now k3s

# --- Download & Configure Promtail Agent ---
PROM_VERSION="2.9.4"
# Escaped $ for Terraform templatefile processing
wget -q "https://github.com/grafana/loki/releases/download/v$${PROM_VERSION}/promtail-linux-amd64.zip"
unzip -o promtail-linux-amd64.zip
mv promtail-linux-amd64 /usr/local/bin/promtail
chmod +x /usr/local/bin/promtail

# Create Promtail configuration directory and file
mkdir -p /etc/promtail
cat <<EOT > /etc/promtail/config.yaml
server:
  http_listen_port: 9080
clients:
  - url: ${loki_url}
    basic_auth:
      username: "${loki_user}"
      password: "${grafana_token}"
scrape_configs:
- job_name: system
  static_configs:
  - targets: [localhost]
    labels:
      job: varlogs
      env: ${env_name}
      __path__: /var/log/*.log
EOT

# Create systemd service unit for Promtail
cat <<EOT > /etc/systemd/system/promtail.service
[Unit]
Description=Promtail Log Collector Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOT

# Reload daemon configurations and enable Promtail
systemctl daemon-reload
systemctl enable --now promtail

#install argocd
chmod +x /usr/local/bin/install-argocd.sh
nohup /usr/local/bin/install-argocd.sh > /var/log/install-argocd.log 2>&1 &