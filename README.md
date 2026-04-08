Observability Stack Setup (Ubuntu) Prometheus + Grafana
+ Node Exporter + Alertmanager

Architecture


Node Exporter → Prometheus → Alertmanager → Email
↓
Grafana

Prerequisites
Ubuntu 20.04/22.04, ports open (9100, 9090, 3000, 9093)

1. Node Exporter Installation

