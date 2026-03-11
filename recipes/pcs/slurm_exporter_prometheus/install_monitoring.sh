# -------------------------------------------------------
# 3. Install slurm_exporter and register as a service
# -------------------------------------------------------
SLURM_EXPORTER_VERSION="1.2.0"
ARCH="amd64"
OS="linux"

# Download the latest pre-compiled release
curl -L -o /tmp/slurm_exporter.tar.gz \
"https://github.com/SckyzO/slurm_exporter/releases/download/v${SLURM_EXPORTER_VERSION}/slurm_exporter-${SLURM_EXPORTER_VERSION}-${OS}-${ARCH}.tar.gz"

# Extract and install binary
tar -xvf /tmp/slurm_exporter.tar.gz -C /tmp/
install -m 0755 /tmp/slurm_exporter /usr/local/bin/slurm_exporter

# Create dedicated system user for the exporter
useradd --no-create-home --shell /bin/false slurm_exporter || true

# Create systemd unit file for slurm_exporter
cat > /etc/systemd/system/slurm_exporter.service << 'EOF'
[Unit]
Description=Prometheus Slurm Exporter
After=network.target slurmctld.service slurmd.service
Wants=network.target

[Service]
User=slurm_exporter
Group=slurm_exporter
Type=simple
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/aws/pcs/scheduler/slurm-25.05/bin"
ExecStart=/usr/local/bin/slurm_exporter \
  --web.listen-address=:9341 \
  --command.timeout=10s \
  --log.level=info \
  --log.format=text
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=slurm_exporter

[Install]
WantedBy=multi-user.target
EOF

# Enable and start slurm_exporter
systemctl daemon-reload
systemctl enable slurm_exporter
systemctl start slurm_exporter

# -------------------------------------------------------
# 4. Install Prometheus and register as a service
# -------------------------------------------------------
PROMETHEUS_VERSION="3.10.0"

# Download Prometheus
curl -L -o /tmp/prometheus.tar.gz \
  "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"

# Extract and install binaries
tar -xzf /tmp/prometheus.tar.gz -C /tmp/
install -m 0755 /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus /usr/local/bin/prometheus
install -m 0755 /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool /usr/local/bin/promtool

# Create Prometheus directories
mkdir -p /etc/prometheus
mkdir -p /var/lib/prometheus

# Create dedicated system user for Prometheus
useradd --no-create-home --shell /bin/false prometheus || true
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Create Prometheus configuration with slurm_exporter scrape job
cat > /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 30s
  evaluation_interval: 30s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'slurm_exporter'
    scrape_interval: 30s
    scrape_timeout: 30s
    static_configs:
      - targets: ['localhost:9341']
EOF

chown prometheus:prometheus /etc/prometheus/prometheus.yml

# Create systemd unit file for Prometheus
cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus Monitoring System
After=network.target
Wants=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=15d \
  --web.listen-address=:9090 \
  --web.enable-lifecycle \
  --log.level=info
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=prometheus

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Prometheus
systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

# Clean up temp files
rm -f /tmp/slurm_exporter.tar.gz /tmp/slurm_exporter
rm -f /tmp/prometheus.tar.gz
rm -rf /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/