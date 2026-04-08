Observability Stack Setup (Ubuntu) Prometheus + Grafana
+ Node Exporter + Alertmanager

Architecture


Node Exporter → Prometheus → Alertmanager → Email
↓
Grafana

Prerequisites
Ubuntu 20.04/22.04, ports open (9100, 9090, 3000, 9093)

1. Node Exporter Installation

execute  these commnds


wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz && tar -xvf node_exporter-1.8.2.linux-amd64.tar.gz && cd node_exporter-1.8.2.linux-amd64 && ./node_exporter


Node Exporter Service 
Create Service File
sudo nano /etc/systemd/system/node_exporter.service

Paste this:

[Unit]
Description=Node Exporter
After=network.target

[Service]
User=ubuntu
Group=ubuntu
Type=simple
ExecStart=/home/ubuntu/node_exporter-1.8.2.linux-amd64/node_exporter
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
✅ Reload + Start + Enable (one-line)
sudo systemctl daemon-reload && sudo systemctl start node_exporter && sudo systemctl enable node_exporter
✅ Verify Service
sudo systemctl status node_exporter


-------------------
2. Prometheus Installation

wget https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz && tar -xvf prometheus-2.52.0.linux-amd64.tar.gz && cd prometheus-2.52.0.linux-amd64

💡 After that (run Prometheus)
./prometheus --config.file=prometheus.yml

Prometheus Config

nano  prometheus.yml

Alert Rules

nano  alert_rules.yml

groups:
  - name: node_alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100) > 80
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "High CPU Usage"
          description: "CPU usage is above 80%"

Prometheus Service

sudo nano  /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
[Service]
ExecStart=/home/ubuntu/prometheus-2.52.0.linux-amd64/prometheus --config.file=/home/ubuntu/prometheus-2.
Restart=always
[Install]
WantedBy=multi-user.target
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus

3. Alertmanager Installation

wget https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd6
tar -xvf alertmanager-0.27.0.linux-amd64.tar.gz
cd alertmanager-0.27.0.linux-amd64
Alertmanager Config
vi alertmanager.yml
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