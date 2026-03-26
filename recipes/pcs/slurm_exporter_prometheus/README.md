# Slurm Exporter and Prometheus Monitoring for AWS PCS
## Info

This recipe provides a comprehensive monitoring solution for AWS Parallel Computing Service (PCS) clusters running Slurm workloads. By deploying Slurm Exporter and Prometheus, you gain deep visibility into your HPC cluster's performance, resource utilization, job queues, and scheduler operations.The monitoring stack consists of two critical services that work together to collect, store, and expose metrics from your Slurm environment:
- *Slurm Exporter (v1.2.0)* - A specialized Prometheus exporter that interfaces directly with Slurm commands to collect cluster-specific metrics including job states, queue depths, node availability, partition information, and scheduler performance. It exposes these metrics on port 9341 for Prometheus to scrape.
- *Prometheus (v3.10.0)* - A powerful time-series database and monitoring system that scrapes metrics from Slurm Exporter every 30 seconds, stores them with 15-day retention, and provides a query interface and web UI on port 9090. This enables you to track trends, set up alerts, and integrate with visualization tools like Grafana.Together, these services provide the foundation for understanding cluster utilization, identifying bottlenecks, optimizing job scheduling, and maintaining operational awareness of your HPC infrastructure.Architecture

Critical Services:
- Slurm Exporter - Runs as slurm_exporter.service, collects metrics via Slurm CLI commands
- Prometheus - Runs as prometheus.service, stores metrics in /var/lib/prometheus
- Both services run as dedicated non-privileged system users for security
- Services automatically restart on failure with 5-second delay

## Prerequisites
Before deploying this monitoring solution, ensure you have:
- AWS PCS cluster with Slurm scheduler deployed and operational
- Root or sudo access on the PCS head nodeNetwork connectivity to download packages from GitHub releases
- Available ports: 9090 (Prometheus) and 9341 (Slurm Exporter)
- Slurm binaries accessible at /opt/aws/pcs/scheduler/slurm-25.05/bin
- Sufficient disk space for metrics storage (recommend 5-10 GB for 15-day retention)

## Usage
### Installation
Run the installation script on your PCS head node:

```bash
chmod +x install_monitoring.sh
sudo ./install_monitoring.sh
```

The script will:
- Download and install Slurm Exporter v1.2.0
- Create dedicated system user slurm_exporter
- Configure and enable slurm_exporter.service
- Download and install Prometheus v3.10.0
- Create dedicated system user prometheus
- Configure Prometheus to scrape Slurm Exporter
- Enable and start prometheus.service

### What Gets Deployed
- *Slurm Exporter*
    - Binary: /usr/local/bin/slurm_exporter
    - Service: /etc/systemd/system/slurm_exporter.service
    - Metrics endpoint: http://[IP_ADDRESS]:9341/metrics
    - Configuration: Embedded in systemd service file
    - User: slurm_exporter (system account)
- *Prometheus*
    - Binary: /usr/local/bin/prometheus
    - Configuration: /etc/prometheus/prometheus.yml
    - Data directory: /var/lib/prometheus
    - Service: /etc/systemd/system/prometheus.service
    - Web UI: http://[IP_ADDRESS]:9090
    - User: prometheus (system account)

### Configuration
#### Slurm Exporter Settings
The exporter is configured with these parameters:
- Listen address: :9341 (all interfaces)
- Command timeout: 10 seconds
- Log level: infoPATH: Includes /opt/aws/pcs/scheduler/slurm-25.05/bin for Slurm commands
- Restart policy: Automatic restart on failure
#### Prometheus Configuration
Default scrape configuration (/etc/prometheus/prometheus.yml):
- Global scrape interval: 30 seconds
- Evaluation interval: 30 seconds
- Retention period: 15 days
- Scrape targets:
    - Prometheus self-monitoring on port 9090
    - Slurm Exporter on port 9341 with 30-second scrape interval

To modify the configuration, edit /etc/prometheus/prometheus.yml and reload

``` bash
sudo systemctl reload prometheus
```

### Verification
#### Check Service Status

```bash
# Verify Slurm Exporter is running
sudo systemctl status slurm_exporter
# Verify Prometheus is running
sudo systemctl status prometheus
```

#### Test Metrics Endpoints
```bash
# Check Slurm Exporter metrics
curl http://[IP_ADDRESS]:9341/metrics

# Check Prometheus metrics
curl http://[IP_ADDRESS]:9090/metric
```

### Access Prometheus Web UI
If you have network access to the head node, navigate to http://<head-node-ip>:9090 to access the Prometheus web interface where you can query metrics and check target health.

#### Available Metrics
##### Key Slurm Metrics
The Slurm Exporter provides comprehensive metrics including:
- Queue metrics: slurm_queue_running, slurm_queue_pending, slurm_queue_suspended
- Node metrics: slurm_nodes_alloc, slurm_nodes_idle, slurm_nodes_down, slurm_nodes_total
- Partition metrics: slurm_partition_nodes_allocated, slurm_partition_cpus_total
- Job metrics: slurm_job_states, slurm_job_count
- Scheduler metrics: Performance and backfill statistics

##### Example Prometheus Queries
Access the Prometheus UI and try these queries:
```bash 
# Current number of running jobs
slurm_queue_running

# Pending jobs over time
rate(slurm_queue_pending[5m])

# Node utilization percentage
(slurm_nodes_alloc / slurm_nodes_total) * 100

# Jobs completed in last hour
increase(slurm_job_complete[1h])
```

### Build Grafana Dashboards
With Prometheus collecting metrics, you can visualize them using Grafana for rich, interactive dashboards. Within your Grafana workspace, select Dashboards > New > Import to get started.

#### Recommended Dashboards
##### 1. Slurm Exporter Dashboard
This dashboard provides comprehensive visualization of Slurm cluster metrics including job queues, node states, and resource utilization.
```
https://grafana.com/grafana/dashboards/4323-slurm-dashboard/
```
Setup: Add your Prometheus instance as a data source (URL: http://<head-node-ip>:9090), then import the dashboard using the URL above.

## Troubleshooting

### Slurm Exporter Issues
Check logs:
```bash
sudo journalctl -u slurm_exporter -f
```
Common issues:
- Can't access Slurm commands: Verify PATH includes Slurm binaries and user has permissions
- Timeout errors: Increase --command.timeout in service file if Slurm commands are slow
- No metrics: Ensure Slurm scheduler is running and accessible

Test Slurm access
```bash
sudo -u slurm_exporter /opt/aws/pcs/scheduler/slurm-25.05/bin/sinfo
```

### Prometheus Issues
Check logs
```bash
sudo journalctl -u prometheus -f
```

Validate configuration
```bash 
/usr/local/bin/promtool check config /etc/prometheus/prometheus.yml
```

Check scrape targets
```bash
curl http://[IP_ADDRESS]:9090/api/v1/targets
```

Common issues:
- Target down: Verify Slurm Exporter is running and port 9341 is accessible
- High memory usage: Reduce retention period or scrape frequency
- Disk space: Monitor /var/lib/prometheus and adjust retention as needed

## Customization
### Adjust Scrape Intervals
Edit /etc/prometheus/prometheus.yml to change how frequently metrics are collected
```bash 
scrape_configs:
  - job_name: 'slurm_exporter'
    scrape_interval: 60s  # Change from default 30s
    scrape_timeout: 30s
    static_configs:
      - targets: ['[IP_ADDRESS]:9341']
```

Then reload: sudo systemctl reload prometheus

### Change Retention Period
Edit /etc/systemd/system/prometheus.service and modify the --storage.tsdb.retention.time flag (default: 15d), then:
```bash 
sudo systemctl daemon-reload
sudo systemctl restart prometheus
```
    
## Cleanup
To remove the monitoring stack:
```bash
# Stop and disable services
sudo systemctl stop slurm_exporter prometheus
sudo systemctl disable slurm_exporter prometheus

# Remove binaries and configuration
sudo rm /usr/local/bin/slurm_exporter
sudo rm /usr/local/bin/prometheus /usr/local/bin/promtool
sudo rm -rf /etc/prometheus /var/lib/prometheus
sudo rm /etc/systemd/system/slurm_exporter.service
sudo rm /etc/systemd/system/prometheus.service

# Remove system users
sudo userdel slurm_exporter
sudo userdel prometheus

# Reload systemd
sudo systemctl daemon-reload
```

## References
* [Slurm Exporter GitHub](https://github.com/SckyzO/slurm_exporter)
* [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)