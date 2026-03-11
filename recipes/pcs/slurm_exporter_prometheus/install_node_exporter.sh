#!/bin/bash
# -------------------------------------------------------
# 1. Install node_exporter and register as a service
# -------------------------------------------------------

# Download node_exporter v1.8.2
curl -L -o /tmp/node_exporter.tar.gz \
  "https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz"

# Extract and install binary
tar -xzf /tmp/node_exporter.tar.gz -C /tmp/
install -m 0755 /tmp/node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/node_exporter

# Create dedicated system user for node_exporter
useradd --no-create-home --shell /bin/false node_exporter || true

# Create systemd unit file for node_exporter
cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Prometheus Node Exporter
After=network.target
Wants=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \
  --web.listen-address=:9100 \
  --collector.systemd \
  --collector.processes
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# -------------------------------------------------------
# 3. Clean up temp files
# -------------------------------------------------------
rm -f /tmp/node_exporter.tar.gz
rm -rf /tmp/node_exporter-1.8.2.linux-amd64/