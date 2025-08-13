#!/bin/bash

# Simple EKS Self-Managed Node Bootstrap Script
set -o xtrace

# Variables passed from Terraform
CLUSTER_NAME="${cluster_name}"
CLUSTER_ENDPOINT="${cluster_endpoint}"
CLUSTER_CA_DATA="${cluster_ca_data}"
BOOTSTRAP_ARGUMENTS="${bootstrap_arguments}"

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/eks-bootstrap.log
}

log "Starting EKS node bootstrap process"

# Get instance metadata using IMDSv2
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)

log "Instance ID: $INSTANCE_ID, Region: $REGION, Cluster: $CLUSTER_NAME"

# Use legacy bootstrap script (works for both AL2 and AL2023)
if [ -f /etc/eks/bootstrap.sh ]; then
    log "Using EKS bootstrap script"
    
    # Construct bootstrap arguments
    BOOTSTRAP_ARGS=""
    if [ ! -z "$BOOTSTRAP_ARGUMENTS" ]; then
        BOOTSTRAP_ARGS="$BOOTSTRAP_ARGUMENTS"
    fi
    
    log "Running: /etc/eks/bootstrap.sh $CLUSTER_NAME $BOOTSTRAP_ARGS"
    /etc/eks/bootstrap.sh $CLUSTER_NAME $BOOTSTRAP_ARGS
    
    if [ $? -eq 0 ]; then
        log "EKS bootstrap completed successfully"
    else
        log "ERROR: EKS bootstrap failed"
        exit 1
    fi
else
    log "ERROR: /etc/eks/bootstrap.sh not found. This may not be an EKS-optimized AMI."
    exit 1
fi

# Verify kubelet is running
log "Verifying kubelet status"
systemctl status kubelet --no-pager

# Wait for node to be ready
log "Waiting for node to join cluster..."
for i in {1..30}; do
    if kubectl --kubeconfig /var/lib/kubelet/kubeconfig get nodes 2>/dev/null | grep -q $(hostname -s); then
        log "Node successfully joined the cluster"
        break
    fi
    log "Waiting for node to appear in cluster... (attempt $i/30)"
    sleep 10
done

log "Node bootstrap completed. Instance $INSTANCE_ID should now be part of cluster $CLUSTER_NAME"