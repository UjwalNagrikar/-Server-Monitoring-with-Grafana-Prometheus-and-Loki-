# Observability Stack on AWS EC2 (Ubuntu)
> **Prometheus · Grafana · Node Exporter · Alertmanager**

A production-ready, end-to-end observability stack for monitoring Linux infrastructure metrics with real-time dashboards and email alerting.

---

## Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Port Reference](#port-reference)
- [Step 1 — Launch & Configure AWS EC2](#step-1--launch--configure-aws-ec2)
- [Step 2 — Node Exporter](#step-2--node-exporter)
- [Step 3 — Prometheus](#step-3--prometheus)
- [Step 4 — Alertmanager](#step-4--alertmanager)
- [Step 5 — Grafana](#step-5--grafana)
- [Step 6 — Connect Prometheus to Grafana](#step-6--connect-prometheus-to-grafana)
- [Step 7 — Import a Dashboard](#step-7--import-a-dashboard)
- [Verification Checklist](#verification-checklist)
- [Troubleshooting](#troubleshooting)

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     AWS EC2 Instance                    │
│                                                         │
│   ┌──────────────┐     scrapes      ┌───────────────┐  │
│   │ Node Exporter│ ───────────────► │   Prometheus  │  │
│   │  :9100       │                  │   :9090       │  │
│   └──────────────┘                  └───────┬───────┘  │
│                                             │           │
│                                    fires    │  queries  │
│                                   alerts    ▼           │
│                              ┌──────────────────────┐  │
│                              │    Alertmanager       │  │
│                              │    :9093              │  │
│                              └──────────┬───────────┘  │
│                                         │               │
│                                    sends email          │
│                                         ▼               │
│                                   📧 Gmail SMTP         │
│                                                         │
│   ┌──────────────┐                                      │
│   │   Grafana    │ ◄──── queries Prometheus             │
│   │   :3000      │                                      │
│   └──────────────┘                                      │
└─────────────────────────────────────────────────────────┘
```

---

## Prerequisites

| Requirement | Detail |
|---|---|
| AWS Account | With EC2 access |
| Instance OS | Ubuntu 20.04 or 22.04 LTS |
| Instance Type | t2.micro (free tier) or larger |
| SSH Access | `.pem` key pair |
| Gmail Account | App password enabled (for alerts) |

---

## Port Reference

| Component | Port | Protocol |
|---|---|---|
| Node Exporter | 9100 | TCP |
| Prometheus | 9090 | TCP |
| Alertmanager | 9093 | TCP |
| Grafana | 3000 | TCP |
| SSH | 22 | TCP |

---

## Step 1 — Launch & Configure AWS EC2

### 1.1 Launch the Instance

1. Go to **AWS Console → EC2 → Launch Instance**
2. Choose **Ubuntu Server 22.04 LTS (HVM), SSD Volume Type**
3. Select instance type: **t2.medium** (recommended) or t2.micro for testing
4. Configure storage: **20 GiB** (default is fine)
5. Create or select an existing key pair
6. Launch the instance

### 1.2 Configure Security Group (Inbound Rules)

Navigate to **EC2 → Security Groups → Inbound Rules → Edit** and add the following:

| Type | Protocol | Port Range | Source | Description |
|---|---|---|---|---|
| SSH | TCP | 22 | My IP | SSH access |
| Custom TCP | TCP | 9090 | My IP | Prometheus UI |
| Custom TCP | TCP | 9100 | My IP | Node Exporter |
| Custom TCP | TCP | 9093 | My IP | Alertmanager UI |
| Custom TCP | TCP | 3000 | My IP | Grafana UI |

> **Security Note:** Restrict source to `My IP` instead of `0.0.0.0/0` in production environments.

### 1.3 Connect to Your Instance

```bash
chmod 400 your-key.pem
ssh -i your-key.pem ubuntu@<EC2-PUBLIC-IP>
```

### 1.4 Update the System

```bash
sudo apt update && sudo apt upgrade -y
```

---

## Step 2 — Node Exporter

Node Exporter exposes hardware and OS metrics (CPU, memory, disk, network) for Prometheus to scrape.

### 2.1 Download & Extract

```bash
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz

tar -xvf node_exporter-1.8.2.linux-amd64.tar.gz

cd node_exporter-1.8.2.linux-amd64
```

### 2.2 Test Run (Optional)

```bash
./node_exporter
```

Visit `http://<EC2-PUBLIC-IP>:9100/metrics` to verify it is serving metrics. Press `Ctrl+C` to stop.

### 2.3 Create a systemd Service

```bash
sudo nano /etc/systemd/system/node_exporter.service
```

Paste the following content:

```ini
[Unit]
Description=Node Exporter
Documentation=https://github.com/prometheus/node_exporter
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
```

### 2.4 Enable & Start the Service

```bash
sudo systemctl daemon-reload && \
sudo systemctl start node_exporter && \
sudo systemctl enable node_exporter
```

### 2.5 Verify

```bash
sudo systemctl status node_exporter
```

Expected output: `Active: active (running)`

```bash
# Confirm metrics are being served
curl http://localhost:9100/metrics | head -20
```

---

## Step 3 — Prometheus

Prometheus scrapes metrics from Node Exporter, stores them as time-series data, and evaluates alert rules.

### 3.1 Download & Extract

```bash
cd ~

wget https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz

tar -xvf prometheus-2.52.0.linux-amd64.tar.gz

cd prometheus-2.52.0.linux-amd64
```

### 3.2 Configure Prometheus

```bash
nano prometheus.yml
```

Replace the contents with the following:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - localhost:9093

rule_files:
  - "alert_rules.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node_exporter"
    static_configs:
      - targets: ["localhost:9100"]
```

### 3.3 Create Alert Rules

```bash
nano alert_rules.yml
```

```yaml
groups:
  - name: node_alerts
    rules:

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100) > 80
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "High CPU Usage on {{ $labels.instance }}"
          description: "CPU usage has exceeded 80% for more than 1 minute. Current value: {{ $value }}%"

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High Memory Usage on {{ $labels.instance }}"
          description: "Memory usage has exceeded 85%. Current value: {{ $value }}%"

      - alert: DiskSpaceLow
        expr: (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low Disk Space on {{ $labels.instance }}"
          description: "Disk usage on {{ $labels.mountpoint }} is above 80%. Current value: {{ $value }}%"

      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ $labels.instance }} is down"
          description: "{{ $labels.instance }} of job {{ $labels.job }} has been unreachable for more than 1 minute."
```

### 3.4 Test the Configuration

```bash
./promtool check config prometheus.yml
```

Expected output: `SUCCESS: prometheus.yml is valid prometheus config file syntax`

### 3.5 Create a systemd Service

```bash
sudo nano /etc/systemd/system/prometheus.service
```

```ini
[Unit]
Description=Prometheus Monitoring System
Documentation=https://prometheus.io/docs/introduction/overview/
After=network.target

[Service]
User=ubuntu
Group=ubuntu
Type=simple
ExecStart=/home/ubuntu/prometheus-2.52.0.linux-amd64/prometheus \
  --config.file=/home/ubuntu/prometheus-2.52.0.linux-amd64/prometheus.yml \
  --storage.tsdb.path=/home/ubuntu/prometheus-2.52.0.linux-amd64/data \
  --web.console.templates=/home/ubuntu/prometheus-2.52.0.linux-amd64/consoles \
  --web.console.libraries=/home/ubuntu/prometheus-2.52.0.linux-amd64/console_libraries \
  --web.listen-address=0.0.0.0:9090
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 3.6 Enable & Start the Service

```bash
sudo systemctl daemon-reload && \
sudo systemctl start prometheus && \
sudo systemctl enable prometheus
```

### 3.7 Verify

```bash
sudo systemctl status prometheus
```

Access the Prometheus UI at: `http://<EC2-PUBLIC-IP>:9090`

Navigate to **Status → Targets** — both `prometheus` and `node_exporter` should show `UP`.

---

## Step 4 — Alertmanager

Alertmanager receives alerts from Prometheus and routes them to configured notification channels (email, Slack, PagerDuty, etc.).

### 4.1 Download & Extract

```bash
cd ~

wget https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz

tar -xvf alertmanager-0.27.0.linux-amd64.tar.gz

cd alertmanager-0.27.0.linux-amd64
```

### 4.2 Generate a Gmail App Password

> Regular Gmail passwords will **not** work. You must generate an App Password.

1. Go to [myaccount.google.com](https://myaccount.google.com)
2. Navigate to **Security → 2-Step Verification** (enable if not already)
3. Go to **Security → App passwords**
4. Select app: **Mail**, device: **Other (Custom name)** → name it `Alertmanager`
5. Copy the 16-character password generated

### 4.3 Configure Alertmanager

```bash
nano alertmanager.yml
```

```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'your-email@gmail.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-16-char-app-password'
  smtp_require_tls: true

route:
  group_by: ['alertname', 'instance']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 3h
  receiver: 'email-alert'

receivers:
  - name: 'email-alert'
    email_configs:
      - to: 'your-email@gmail.com'
        send_resolved: true
        headers:
          Subject: '[{{ .Status | toUpper }}] {{ .CommonAnnotations.summary }}'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
```

> Replace `your-email@gmail.com` and `your-16-char-app-password` with your actual values.

### 4.4 Create a systemd Service

```bash
sudo nano /etc/systemd/system/alertmanager.service
```

```ini
[Unit]
Description=Alertmanager
Documentation=https://prometheus.io/docs/alerting/latest/alertmanager/
After=network.target

[Service]
User=ubuntu
Group=ubuntu
Type=simple
ExecStart=/home/ubuntu/alertmanager-0.27.0.linux-amd64/alertmanager \
  --config.file=/home/ubuntu/alertmanager-0.27.0.linux-amd64/alertmanager.yml \
  --storage.path=/home/ubuntu/alertmanager-0.27.0.linux-amd64/data
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 4.5 Enable & Start the Service

```bash
sudo systemctl daemon-reload && \
sudo systemctl start alertmanager && \
sudo systemctl enable alertmanager
```

### 4.6 Verify

```bash
sudo systemctl status alertmanager
```

Access Alertmanager UI at: `http://<EC2-PUBLIC-IP>:9093`

---

## Step 5 — Grafana

Grafana connects to Prometheus as a data source and provides rich, interactive dashboards.

### 5.1 Install Grafana

```bash
sudo apt update && \
sudo apt install -y apt-transport-https software-properties-common wget && \
sudo mkdir -p /etc/apt/keyrings && \
wget -q -O - https://apt.grafana.com/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/grafana.gpg && \
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | \
sudo tee /etc/apt/sources.list.d/grafana.list && \
sudo apt update && \
sudo apt install -y grafana
```

### 5.2 Start & Enable Grafana

```bash
sudo systemctl start grafana-server && \
sudo systemctl enable grafana-server
```

### 5.3 Verify

```bash
sudo systemctl status grafana-server
```

Access Grafana at: `http://<EC2-PUBLIC-IP>:3000`

Default credentials:
- **Username:** `admin`
- **Password:** `admin`

> You will be prompted to change the password on first login.

---

## Step 6 — Connect Prometheus to Grafana

1. Log into Grafana at `http://<EC2-PUBLIC-IP>:3000`
2. In the left sidebar, go to **Connections → Data Sources**
3. Click **Add data source**
4. Select **Prometheus**
5. Set the URL to: `http://localhost:9090`
6. Click **Save & Test**

Expected result: ✅ `Successfully queried the Prometheus API`

---

## Step 7 — Import a Dashboard

Instead of building dashboards from scratch, import the official Node Exporter dashboard.

1. In Grafana, click the **+** icon → **Import**
2. Enter dashboard ID: **`1860`** (Node Exporter Full)
3. Click **Load**
4. Select your Prometheus data source from the dropdown
5. Click **Import**

You now have a comprehensive dashboard with CPU, memory, disk, network, and system load metrics.

---

## Verification Checklist

Run through each checkpoint after completing the setup:

```bash
# 1. Check all services are running
sudo systemctl status node_exporter prometheus alertmanager grafana-server

# 2. Verify ports are listening
ss -tlnp | grep -E '9100|9090|9093|3000'

# 3. Check Prometheus targets (should all be UP)
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool | grep health

# 4. Check alert rules are loaded
curl -s http://localhost:9090/api/v1/rules | python3 -m json.tool
```

| URL | Expected |
|---|---|
| `http://<IP>:9100/metrics` | Raw metrics text |
| `http://<IP>:9090` | Prometheus UI |
| `http://<IP>:9090/targets` | All targets `UP` |
| `http://<IP>:9093` | Alertmanager UI |
| `http://<IP>:3000` | Grafana login page |

---

## Troubleshooting

### Service fails to start

```bash
# View detailed logs
sudo journalctl -u node_exporter -f
sudo journalctl -u prometheus -f
sudo journalctl -u alertmanager -f
sudo journalctl -u grafana-server -f
```

### Prometheus targets show DOWN

- Confirm the target service is running: `sudo systemctl status node_exporter`
- Check the correct port is open in the Security Group
- Verify the `prometheus.yml` target address matches the actual host/port

### Alerts not firing

```bash
# Validate prometheus config
cd ~/prometheus-2.52.0.linux-amd64
./promtool check config prometheus.yml
./promtool check rules alert_rules.yml
```

### Emails not being received

- Verify Gmail 2FA is enabled and the App Password is correct
- Check Alertmanager logs: `sudo journalctl -u alertmanager -f`
- Confirm the Alertmanager UI (`http://<IP>:9093`) shows active alerts

### Permission denied errors

```bash
# Ensure the ubuntu user owns the installation directories
sudo chown -R ubuntu:ubuntu /home/ubuntu/prometheus-2.52.0.linux-amd64
sudo chown -R ubuntu:ubuntu /home/ubuntu/node_exporter-1.8.2.linux-amd64
sudo chown -R ubuntu:ubuntu /home/ubuntu/alertmanager-0.27.0.linux-amd64
```

---

## Component Versions

| Component | Version |
|---|---|
| Node Exporter | v1.8.2 |
| Prometheus | v2.52.0 |
| Alertmanager | v0.27.0 |
| Grafana | Latest Stable |

---


---

> **Author:** Ujwal Nagrikar · [GitHub](https://github.com/UjwalNagrikar) · [LinkedIn](https://linkedin.com/in/ujwal-nagrikar)