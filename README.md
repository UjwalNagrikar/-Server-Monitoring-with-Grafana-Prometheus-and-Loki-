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