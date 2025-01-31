#!/bin/bash
# Monitoring and alerts configuration module

source "$(dirname "$0")/../common/utils.sh"

setup_monitoring() {
    log_message "Setting up monitoring and alerts system..."
    
    # Install monitoring packages
    install_monitoring_packages
    
    # Configure Prometheus
    setup_prometheus
    
    # Configure Grafana
    setup_grafana
    
    # Setup alert manager
    setup_alertmanager
    
    # Configure system monitoring
    setup_node_exporter
    
    # Setup custom monitoring scripts
    setup_custom_monitors
    
    log_message "${GREEN}Monitoring setup complete${NC}"
}

install_monitoring_packages() {
    apt-get install -y \
        prometheus \
        prometheus-alertmanager \
        grafana \
        prometheus-node-exporter \
        prometheus-blackbox-exporter \
        netdata
}

setup_prometheus() {
    cat > /etc/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

rule_files:
  - "/etc/prometheus/rules/*.yml"

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
  
  - job_name: 'radio_metrics'
    static_configs:
      - targets: ['localhost:9101']
  
  - job_name: 'sensor_metrics'
    static_configs:
      - targets: ['localhost:9102']
EOF

    # Create alert rules
    mkdir -p /etc/prometheus/rules
    cat > /etc/prometheus/rules/nafo_alerts.yml << EOF
groups:
  - name: nafo_alerts
    rules:
      - alert: HighTemperature
        expr: sensor_temperature > 30
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: High temperature detected
          
      - alert: LowDiskSpace
        expr: node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100 < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: Low disk space
          
      - alert: RAIDDegradation
        expr: node_md_disks{state="failed"} > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: RAID array degraded
EOF

    systemctl restart prometheus
}

setup_grafana() {
    # Configure Grafana
    cat > /etc/grafana/grafana.ini << EOF
[server]
http_port = 3000
domain = localhost

[security]
admin_user = nafo_admin
admin_password = secure_grafana_password

[auth.anonymous]
enabled = false

[dashboards]
default_home_dashboard_path = /var/lib/grafana/dashboards/nafo_overview.json
EOF

    # Create default dashboard
    mkdir -p /var/lib/grafana/dashboards
    cat > /var/lib/grafana/dashboards/nafo_overview.json << EOF
{
  "dashboard": {
    "title": "NAFO Radio Overview",
    "panels": [
      {
        "title": "System Health",
        "type": "stat"
      },
      {
        "title": "Radio Activity",
        "type": "graph"
      },
      {
        "title": "Environmental Sensors",
        "type": "gauge"
      }
    ]
  }
}
EOF

    systemctl restart grafana-server
}

setup_alertmanager() {
    cat > /etc/prometheus/alertmanager.yml << EOF
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'nafo-alerts'

receivers:
  - name: 'nafo-alerts'
    webhook_configs:
      - url: 'http://localhost:9000/alert'
EOF

    systemctl restart prometheus-alertmanager
}

setup_node_exporter() {
    # Configure node exporter for system metrics
    cat > /etc/default/prometheus-node-exporter << EOF
ARGS="--collector.textfile.directory=/var/lib/prometheus/node-exporter"
EOF

    mkdir -p /var/lib/prometheus/node-exporter
    systemctl restart prometheus-node-exporter
}

setup_custom_monitors() {
    # Create custom monitoring script
    cat > /usr/local/bin/nafo_monitor.py << 'EOF'
#!/usr/bin/env python3
import time
import psutil
import json
from prometheus_client import start_http_server, Gauge

# Define metrics
cpu_temp = Gauge('nafo_cpu_temperature', 'CPU Temperature in Celsius')
raid_status = Gauge('nafo_raid_status', 'RAID Array Status')
radio_signal = Gauge('nafo_radio_signal', 'Radio Signal Strength')

def collect_metrics():
    while True:
        # CPU temperature
        temp = psutil.sensors_temperatures().get('cpu_thermal', [{}])[0].current
        cpu_temp.set(temp)
        
        # RAID status
        with open('/proc/mdstat', 'r') as f:
            raid_ok = 1 if '[UU]' in f.read() else 0
        raid_status.set(raid_ok)
        
        # Radio signal strength (example)
        with open('/storage/radio/signal_strength.log', 'r') as f:
            signal = float(f.read().strip() or 0)
        radio_signal.set(signal)
        
        time.sleep(15)

if __name__ == '__main__':
    start_http_server(9101)
    collect_metrics()
EOF

    chmod +x /usr/local/bin/nafo_monitor.py

    # Create systemd service
    cat > /etc/systemd/system/nafo-monitor.service << EOF
[Unit]
Description=NAFO Radio Custom Monitoring
After=network.target

[Service]
ExecStart=/usr/local/bin/nafo_monitor.py
Restart=always
User=nafo_admin

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable nafo-monitor
    systemctl start nafo-monitor
} 