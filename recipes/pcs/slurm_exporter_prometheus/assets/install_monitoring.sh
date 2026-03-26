
#!/bin/bash
# ============================================================
# install_monitoring.sh
# Installs slurm_exporter and Prometheus on the PCS head node.
# Prometheus is configured with EC2 service discovery to
# dynamically scrape node_exporter on all PCS compute nodes.
#
# Prerequisites:
#   - node_exporter must be installed on all compute nodes
#     (via compute node user data) listening on port 9100
#   - The head node IAM role must have ec2:DescribeInstances
#     permission for EC2 service discovery to work
#   - AWS region must be set correctly below
# ============================================================

set -euo pipefail

# -------------------------------------------------------
# Configuration
# -------------------------------------------------------
SLURM_EXPORTER_VERSION="1.5.1"
PROMETHEUS_VERSION="2.51.2"
AWS_REGION="us-east-1"

# Tag used by PCS to identify compute nodes — adjust if needed
PCS_TAG_KEY="aws:pcs:compute-node-group"

SLURM_BIN="/opt/aws/pcs/scheduler/slurm-25.05/bin"
BASE_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# -------------------------------------------------------
# 1. Install slurm_exporter
# -------------------------------------------------------
echo "[1/4] Installing slurm_exporter v${SLURM_EXPORTER_VERSION}..."

curl -L -o /tmp/slurm_exporter.tar.gz \
  "https://github.com/SckyzO/slurm_exporter/releases/download/v${SLURM_EXPORTER_VERSION}/slurm_exporter-${SLURM_EXPORTER_VERSION}-linux-amd64.tar.gz"


tar -xzf /tmp/slurm_exporter.tar.gz -C /tmp/
install -m 0755 /tmp/slurm_exporter /usr/local/bin/slurm_exporter

useradd --no-create-home --shell /bin/false slurm_exporter || true

cat > /etc/systemd/system/slurm_exporter.service << EOF
[Unit]
Description=Prometheus Slurm Exporter
After=network.target slurmctld.service slurmd.service
Wants=network.target

[Service]
User=slurm_exporter
Group=slurm_exporter
Type=simple
Environment="PATH=${BASE_PATH}:${SLURM_BIN}"
ExecStart=/usr/local/bin/slurm_exporter \\
  --web.listen-address=:9341 \\
  --command.timeout=10s \\
  --log.level=info \\
  --log.format=text
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=slurm_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable slurm_exporter
systemctl start slurm_exporter
echo "  slurm_exporter started on :9341"

# -------------------------------------------------------
# 2. Install Prometheus
# -------------------------------------------------------
echo "[2/4] Installing Prometheus v${PROMETHEUS_VERSION}..."

curl -L -o /tmp/prometheus.tar.gz \
  "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"

tar -xzf /tmp/prometheus.tar.gz -C /tmp/
install -m 0755 /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus /usr/local/bin/prometheus
install -m 0755 /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool /usr/local/bin/promtool

mkdir -p /etc/prometheus /var/lib/prometheus
useradd --no-create-home --shell /bin/false prometheus || true

# -------------------------------------------------------
# 3. Configure Prometheus with EC2 service discovery
# -------------------------------------------------------
echo "[3/4] Writing Prometheus configuration..."

# Detect the head node's private IP at runtime
HEAD_NODE_IP=$(curl -s http://[IP_ADDRESS]/latest/meta-data/local-ipv4)

cat > /etc/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 30s
  evaluation_interval: 30s

scrape_configs:

  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['${HEAD_NODE_IP}:9090']

  # Slurm exporter (head node only)
  - job_name: 'slurm_exporter'
    scrape_interval: 30s
    scrape_timeout: 30s
    static_configs:
      - targets: ['${HEAD_NODE_IP}:9341']
        labels:
          node_type: 'head'

  # node_exporter on the head node (static)
  - job_name: 'node_exporter_head'
    static_configs:
      - targets: ['${HEAD_NODE_IP}:9100']
        labels:
          node_type: 'head'

  # node_exporter on PCS compute nodes (dynamic via EC2 service discovery)
  # Requires: ec2:DescribeInstances on the head node IAM role
  - job_name: 'node_exporter_compute'
    scrape_interval: 30s
    scrape_timeout: 25s
    ec2_sd_configs:
      - region: ${AWS_REGION}
        port: 9100
        filters:
          - name: tag-key
            values: ['${PCS_TAG_KEY}']
          - name: instance-state-name
            values: ['running']
    relabel_configs:
      # Use the private IP as the scrape target
      - source_labels: [__meta_ec2_private_ip]
        target_label: __address__
        replacement: '\${1}:9100'
      # Carry useful labels from EC2 tags/metadata
      - source_labels: [__meta_ec2_private_ip]
        target_label: instance
      - source_labels: [__meta_ec2_tag_Name]
        target_label: node_name
      - source_labels: [__meta_ec2_tag_aws_pcs_compute_node_group]
        target_label: node_group
      - source_labels: [__meta_ec2_instance_type]
        target_label: instance_type
      - source_labels: [__meta_ec2_availability_zone]
        target_label: availability_zone
EOF

chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Validate the config
promtool check-config /etc/prometheus/prometheus.yml

# -------------------------------------------------------
# 4. Start Prometheus
# -------------------------------------------------------
echo "[4/4] Starting Prometheus..."

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

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus
echo "  Prometheus started on :9090"

# -------------------------------------------------------
# Cleanup
# -------------------------------------------------------
rm -f /tmp/slurm_exporter.tar.gz /tmp/slurm_exporter
rm -f /tmp/prometheus.tar.gz
rm -rf /tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/

echo ""
echo "============================================================"
echo " Monitoring stack installed successfully."
echo "  Prometheus:      http://${HEAD_NODE_IP}:9090"
echo "  slurm_exporter:  http://${HEAD_NODE_IP}:9341/metrics"
echo "  node_exporter:   http://${HEAD_NODE_IP}:9100/metrics"
echo "============================================================"