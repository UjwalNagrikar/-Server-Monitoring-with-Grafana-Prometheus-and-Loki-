


Here is the complete documentation in raw Markdown format. You can copy the code block below and paste it directly into your `README.md` file:

```markdown
# 📊 Observability Stack Setup on AWS EC2 (Ubuntu)
**Prometheus + Grafana + Node Exporter + Alertmanager**

A comprehensive guide to setting up a complete observability and monitoring stack on an AWS EC2 instance running Ubuntu 20.04/22.04.

## 🏗 Architecture

```text
[ Server Metrics ]      [ Metrics Scraping ][ Alert Routing ]        [ Notification ]
  Node Exporter    ──→      Prometheus       ──→    Alertmanager     ──→       Email
                                │
                                ↓
                           [ Dashboard ]
                              Grafana
```

## 📋 Prerequisites

1. **AWS EC2 Instance:** Running Ubuntu 20.04 or 22.04.
2. **Security Group Rules (Inbound):** Ensure the following ports are open in your AWS Security Group:
   - `22` (SSH) - Your IP
   - `9090` (Prometheus UI) - `0.0.0.0/0` (or restricted to your IP)
   - `3000` (Grafana UI) - `0.0.0.0/0`
   - `9100` (Node Exporter) - Optional (usually kept internal)
   - `9093` (Alertmanager) - Optional (usually kept internal)
3. **App Password:** An App Password from your Gmail account for Alertmanager to send emails.

---

## 1️⃣ Node Exporter Installation

Node Exporter collects system metrics (CPU, RAM, Disk, etc.).

### Download and Extract
```bash
cd ~
wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar -xvf node_exporter-1.8.2.linux-amd64.tar.gz
```

### Create Systemd Service
```bash
sudo nano /etc/systemd/system/node_exporter.service
```
**Paste the following configuration:**
```ini
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
```

### Start and Enable Node Exporter
```bash
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter
```
✅ **Verify Service:** `sudo systemctl status node_exporter`

---

## 2️⃣ Prometheus Installation

Prometheus acts as the time-series database that scrapes metrics from Node Exporter.

### Download and Extract
```bash
cd ~
wget https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz
tar -xvf prometheus-2.52.0.linux-amd64.tar.gz
cd prometheus-2.52.0.linux-amd64
```

### Configure Prometheus
Replace the default config to link Node Exporter and Alertmanager.
```bash
nano prometheus.yml
```
**Add/Modify to match this:**
```yaml
global:
  scrape_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:['localhost:9093']

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

### Create Alert Rules
```bash
nano alert_rules.yml
```
**Paste the following:**
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
          summary: "High CPU Usage"
          description: "CPU usage is above 80%"
```

### Create Systemd Service
```bash
sudo nano /etc/systemd/system/prometheus.service
```
**Paste the following configuration:**
```ini
[Unit]
Description=Prometheus
After=network.target

[Service]
User=ubuntu
Group=ubuntu
ExecStart=/home/ubuntu/prometheus-2.52.0.linux-amd64/prometheus \
    --config.file=/home/ubuntu/prometheus-2.52.0.linux-amd64/prometheus.yml
Restart=always

[Install]
WantedBy=multi-user.target
```

### Start and Enable Prometheus
```bash
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus
```
✅ **Verify Service:** `sudo systemctl status prometheus`

---

## 3️⃣ Alertmanager Installation

Alertmanager handles alerts sent by Prometheus and routes them to receivers (like Email).

### Download and Extract
```bash
cd ~
wget https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz
tar -xvf alertmanager-0.27.0.linux-amd64.tar.gz
cd alertmanager-0.27.0.linux-amd64
```

### Configure Alertmanager
```bash
nano alertmanager.yml
```
**Paste the following (ensure you use a valid Gmail App Password):**
```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'your-email@gmail.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'
  smtp_require_tls: true

route:
  receiver: 'email-alert'

receivers:
  - name: 'email-alert'
    email_configs:
      - to: 'your-email@gmail.com'
```

### Create Systemd Service
```bash
sudo nano /etc/systemd/system/alertmanager.service
```
**Paste the following:**
```ini
[Unit]
Description=Alertmanager
After=network.target[Service]
User=ubuntu
Group=ubuntu
ExecStart=/home/ubuntu/alertmanager-0.27.0.linux-amd64/alertmanager \
    --config.file=/home/ubuntu/alertmanager-0.27.0.linux-amd64/alertmanager.yml
Restart=always

[Install]
WantedBy=multi-user.target
```

### Start and Enable Alertmanager
```bash
sudo systemctl daemon-reload
sudo systemctl start alertmanager
sudo systemctl enable alertmanager
```
✅ **Verify Service:** `sudo systemctl status alertmanager`

---

## 4️⃣ Grafana Installation

Grafana visualizes the metrics scraped by Prometheus.

### Install Grafana via APT Repository
```bash
sudo apt update
sudo apt install -y apt-transport-https software-properties-common wget
sudo mkdir -p /etc/apt/keyrings
wget -q -O - https://apt.grafana.com/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt update
sudo apt install -y grafana
```

### Start and Enable Grafana
```bash
sudo systemctl start grafana-server
sudo systemctl enable grafana-server
```
✅ **Verify Service:** `sudo systemctl status grafana-server`

---

## 🚀 5️⃣ Final Steps & Verification

### 1. Access the UIs
Open your browser and navigate to your EC2 Public IP address:
- **Prometheus:** `http://<EC2-PUBLIC-IP>:9090` (Check `Status` -> `Targets` to ensure Node Exporter is UP).
- **Grafana:** `http://<EC2-PUBLIC-IP>:3000`

### 2. Configure Grafana
1. Log in to Grafana. Default credentials are:
   - **Username:** `admin`
   - **Password:** `admin` (You will be prompted to change this immediately).
2. Go to **Connections** > **Data Sources** > **Add Data Source**.
3. Select **Prometheus**.
4. Set the URL to: `http://localhost:9090`.
5. Scroll down and click **Save & Test**.

### 3. Import a Dashboard
1. Go to **Dashboards** > **Import**.
2. Enter the dashboard ID **`1860`** (Standard Node Exporter Full Dashboard).
3. Click **Load**.
4. Select the Prometheus data source you just created from the dropdown.
5. Click **Import**. You should now see live server metrics!
```