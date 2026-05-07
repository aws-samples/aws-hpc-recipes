#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

set -e
export GOPATH=/usr/local/go

# Log all output for debugging
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting Monitoring installation..."

# Wait for Docker to be ready
sleep 10

# Pin to specific commit for supply chain security (R-1 from threat model)
REPO_COMMIT="43b7d6515336a55bf4f93e4bca3fe6f4f960af59"

# Clone monitoring repo at pinned commit
mkdir -p /opt/pcs/monitoring
cd /opt/pcs/monitoring
git clone https://github.com/aws-samples/awsome-distributed-training.git
cd awsome-distributed-training
git checkout "$REPO_COMMIT"

# Verify the checkout succeeded at the expected commit
ACTUAL_COMMIT=$(git rev-parse HEAD)
if [ "$ACTUAL_COMMIT" != "$REPO_COMMIT" ]; then
    echo "ERROR: Git checkout integrity check failed. Expected $REPO_COMMIT but got $ACTUAL_COMMIT"
    exit 1
fi
echo "Verified repository pinned at commit: $ACTUAL_COMMIT"

cd 1.architectures/5.sagemaker-hyperpod/LifecycleScripts/base-config/observability/

# Add urllib.request import after existing imports
sed -i '/^import socket$/a\
import urllib.request' install_observability.py

# Replace the get_region_from_resource_config function
sed -i '/^def get_region_from_resource_config():/,/^    return region$/c\
def get_region_from_imds():\
    # Get IMDSv2 token\
    token_req = urllib.request.Request(\
        "http://169.254.169.254/latest/api/token",\
        headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"},\
        method="PUT"\
    )\
    with urllib.request.urlopen(token_req) as response:\
        token = response.read().decode()\
    \
    # Get region using token\
    region_req = urllib.request.Request(\
        "http://169.254.169.254/latest/meta-data/placement/region",\
        headers={"X-aws-ec2-metadata-token": token}\
    )\
    with urllib.request.urlopen(region_req) as response:\
        return response.read().decode()' install_observability.py

# Update function call
sed -i 's/get_region_from_resource_config()/get_region_from_imds()/g' install_observability.py

# Update Slurm Check
sed -i 's/slurmctld/slurmd/g' install_slurm_exporter.sh
sed -i '/make build/i\    # Set required environment variables for Go build\n    export HOME=/root\n    export GOCACHE=/tmp/go-cache\n    mkdir -p $GOCACHE\n' install_slurm_exporter.sh

# Patch slurm_exporter systemd unit to source Slurm environment (needed for Ubuntu)
sed -i 's|ExecStart=/usr/bin/slurm_exporter|ExecStart=/bin/bash -c "source /etc/profile.d/slurm.sh \&\& exec /usr/bin/slurm_exporter"|' install_slurm_exporter.sh

# Add custom jobs collector to slurm_exporter for job-level metrics
# Write a patch script that will be called from inside install_slurm_exporter.sh
# after git clone but before make build (runs inside the slurm_exporter directory)
cat > /tmp/patch_slurm_exporter.sh << 'PATCHEOF'
#!/bin/bash
set -e
echo "Patching slurm_exporter with jobs collector..."

# Add "jobs" collector entry to main.go
sed -i '/"gpus":/a\\t"jobs":         func(l *logger.Logger) prometheus.Collector { return collector.NewJobsCollector(l) },' cmd/slurm_exporter/main.go

# Create jobs.go collector file
cat > internal/collector/jobs.go << 'GOEOF'
package collector

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/sckyzo/slurm_exporter/internal/logger"
)

func JobsData(logger *logger.Logger) ([]byte, error) {
	return Execute(logger, "squeue", []string{"-h", "-o", "%i,%j,%P,%N", "--states=RUNNING"})
}

type JobNodeMapping struct {
	jobID     string
	jobName   string
	partition string
	nodes     []string
}

func ParseJobsMetrics(logger *logger.Logger) ([]JobNodeMapping, error) {
	var jobMappings []JobNodeMapping
	jobsData, err := JobsData(logger)
	if err != nil {
		return nil, err
	}
	lines := strings.Split(string(jobsData), "\n")
	for _, line := range lines {
		if line == "" {
			continue
		}
		fields := strings.Split(line, ",")
		if len(fields) < 4 {
			continue
		}
		jobID := fields[0]
		jobName := fields[1]
		partition := fields[2]
		nodeList := fields[3]
		nodes := parseNodeList(nodeList)
		for _, node := range nodes {
			jobMappings = append(jobMappings, JobNodeMapping{jobID: jobID, jobName: jobName, partition: partition, nodes: []string{node}})
		}
	}
	return jobMappings, nil
}

func parseNodeList(nodeList string) []string {
	var nodes []string
	parts := strings.Split(nodeList, ",")
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		if strings.Contains(part, "[") && strings.Contains(part, "]") {
			nodes = append(nodes, expandNodeRange(part)...)
		} else {
			nodes = append(nodes, part)
		}
	}
	return nodes
}

func expandNodeRange(nodeRange string) []string {
	var nodes []string
	bracketStart := strings.Index(nodeRange, "[")
	bracketEnd := strings.Index(nodeRange, "]")
	if bracketStart == -1 || bracketEnd == -1 {
		return []string{nodeRange}
	}
	prefix := nodeRange[:bracketStart]
	rangeStr := nodeRange[bracketStart+1 : bracketEnd]
	if strings.Contains(rangeStr, "-") {
		rangeParts := strings.Split(rangeStr, "-")
		if len(rangeParts) == 2 {
			start, err1 := strconv.Atoi(rangeParts[0])
			end, err2 := strconv.Atoi(rangeParts[1])
			if err1 == nil && err2 == nil {
				padding := len(rangeParts[0])
				for i := start; i <= end; i++ {
					nodes = append(nodes, prefix+fmt.Sprintf("%0*d", padding, i))
				}
				return nodes
			}
		}
	}
	nodeNums := strings.Split(rangeStr, ",")
	for _, nodeNum := range nodeNums {
		nodeNum = strings.TrimSpace(nodeNum)
		if nodeNum != "" {
			nodes = append(nodes, prefix+nodeNum)
		}
	}
	return nodes
}

type JobsCollector struct {
	jobNodeInfo *prometheus.Desc
	logger      *logger.Logger
}

func NewJobsCollector(logger *logger.Logger) *JobsCollector {
	labels := []string{"job_id", "job_name", "partition", "node_name"}
	return &JobsCollector{
		jobNodeInfo: prometheus.NewDesc("slurm_job_node_info", "Slurm job to node mapping", labels, nil),
		logger:      logger,
	}
}

func (jc *JobsCollector) Describe(ch chan<- *prometheus.Desc) {
	ch <- jc.jobNodeInfo
}

func (jc *JobsCollector) Collect(ch chan<- prometheus.Metric) {
	jobMappings, err := ParseJobsMetrics(jc.logger)
	if err != nil {
		jc.logger.Error("Failed to parse jobs metrics", "err", err)
		return
	}
	for _, mapping := range jobMappings {
		for _, node := range mapping.nodes {
			labels := []string{mapping.jobID, mapping.jobName, mapping.partition, node}
			ch <- prometheus.MustNewConstMetric(jc.jobNodeInfo, prometheus.GaugeValue, 1, labels...)
		}
	}
}
GOEOF

echo "Jobs collector patch applied successfully."
PATCHEOF
chmod +x /tmp/patch_slurm_exporter.sh

# Inject call to patch script into install_slurm_exporter.sh (after cd slurm_exporter, before make build)
sed -i '/cd slurm_exporter/a\    /tmp/patch_slurm_exporter.sh' install_slurm_exporter.sh

# Update OTEL Collector Config
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_TYPE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-type)
AZ_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone-id)
PCS_COMPUTENODEGROUPID_TAG=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/tags/instance/aws:pcs:compute-node-group-id)
PCS_CLUSTERID_TAG=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/tags/instance/aws:pcs:cluster-id)
SCONTROL_PATH=$(whereis scontrol | awk '{print $2}')
while [ ! -x "$SCONTROL_PATH" ]; do
	sleep 15
	[ -f /etc/profile.d/slurm.sh ] && source /etc/profile.d/slurm.sh
    SCONTROL_PATH=$(whereis scontrol | awk '{print $2}')
done

while ! $SCONTROL_PATH show node >/dev/null 2>&1; do
    sleep 15
done
SLURM_NODE_NAME=$($SCONTROL_PATH show node | grep -B15 "InstanceId=$INSTANCE_ID" | grep NodeName | awk -F= '{print $2}' | awk '{print $1}')
PARTITION_NAME=$($SCONTROL_PATH show node | grep -B16 "InstanceId=$INSTANCE_ID" | grep Partitions | awk -F= '{print $2}' | awk '{print $1}')

sed -i "/target_label: instance\b/,/replacement:/ s/replacement:.*/&\n            - target_label: slurm_node\n              replacement: '$SLURM_NODE_NAME'/" otel_config/config-head-template.yaml
sed -i "/target_label: instance\b/,/replacement:/ s/replacement:.*/&\n            - target_label: instance_id\n              replacement: '$INSTANCE_ID'/" otel_config/config-head-template.yaml
sed -i "/target_label: instance\b/,/replacement:/ s/replacement:.*/&\n            - target_label: instance_type\n              replacement: '$INSTANCE_TYPE'/" otel_config/config-head-template.yaml
sed -i "/target_label: instance\b/,/replacement:/ s/replacement:.*/&\n            - target_label: availability_zone_id\n              replacement: '$AZ_ID'/" otel_config/config-head-template.yaml
sed -i "/target_label: instance\b/,/replacement:/ s/replacement:.*/&\n            - target_label: pcs_cluster_id\n              replacement: '$PCS_CLUSTERID_TAG'/" otel_config/config-head-template.yaml
sed -i "/target_label: instance\b/,/replacement:/ s/replacement:.*/&\n            - target_label: pcs_compute_node_group_id\n              replacement: '$PCS_COMPUTENODEGROUPID_TAG'/" otel_config/config-head-template.yaml

# Get prometheus configuration
PROM_PARAM_VALUE=$(aws ssm get-parameter --name "<PROMETHEUS_SSM_PARAM>" --with-decryption --query "Parameter.Value" --output text)

# Run installation script
python3 -u install_observability.py --node-type controller --prometheus-remote-write-url $PROM_PARAM_VALUE
