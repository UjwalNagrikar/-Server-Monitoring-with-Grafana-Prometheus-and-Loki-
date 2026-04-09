#!/bin/bash

# update system
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y wget tar curl

# create users
sudo useradd --no-create-home --shell /bin/false prometheus || true
sudo useradd --no-create-home --shell /bin/false node_exporter || true
sudo useradd --no-create-home --shell /bin/false alertmanager || true

# install node exporter
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar -xzf node_exporter-1.8.2.linux-amd64.tar.gz
sudo cp node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

# node exporter service
cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# install prometheus
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz
tar -xzf prometheus-2.52.0.linux-amd64.tar.gz

sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo cp prometheus-2.52.0.linux-amd64/prometheus /usr/local/bin/
sudo cp prometheus-2.52.0.linux-amd64/promtool /usr/local/bin/
sudo cp -r prometheus-2.52.0.linux-amd64/consoles /etc/prometheus/
sudo cp -r prometheus-2.52.0.linux-amd64/console_libraries /etc/prometheus/

sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus /usr/local/bin/prometheus

# alert rules
cat <<EOF | sudo tee /etc/prometheus/alert_rules.yml
groups:
- name: node_alerts
  rules:
  - alert: HighCPUUsage
    expr: 100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100) > 80
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High CPU usage"
EOF

# prometheus config
cat <<EOF | sudo tee /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

rule_files:
  - "/etc/prometheus/alert_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']
EOF

# prometheus service
cat <<EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.listen-address=:9090
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# install alertmanager
cd /tmp
wget https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz
tar -xzf alertmanager-0.27.0.linux-amd64.tar.gz
sudo mkdir -p /etc/alertmanager
sudo cp alertmanager-0.27.0.linux-amd64/alertmanager /usr/local/bin/
sudo chown alertmanager:alertmanager /usr/local/bin/alertmanager

# alertmanager config (update email + app password)
cat <<EOF | sudo tee /etc/alertmanager/alertmanager.yml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'your-email@gmail.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'

route:
  receiver: 'email-alert'

receivers:
- name: 'email-alert'
  email_configs:
  - to: 'your-email@gmail.com'
EOF

# alertmanager service
cat <<EOF | sudo tee /etc/systemd/system/alertmanager.service
[Unit]
Description=Alertmanager
After=network.target

[Service]
User=alertmanager
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --web.listen-address=:9093
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# install grafana
sudo apt install -y apt-transport-https software-properties-common
sudo mkdir -p /etc/apt/keyrings
wget -q -O - https://apt.grafana.com/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

sudo apt update
sudo apt install -y grafana

# start services
sudo systemctl daemon-reload
sudo systemctl enable node_exporter prometheus alertmanager grafana-server
sudo systemctl start node_exporter prometheus alertmanager grafana-server

# output
echo "Prometheus: http://<your-ip>:9090"
echo "Alertmanager: http://<your-ip>:9093"
echo "Grafana: http://<your-ip>:3000"

