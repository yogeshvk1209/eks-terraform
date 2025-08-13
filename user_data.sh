#!/bin/bash

# EKS Self-Managed Node Bootstrap Script for AL2023
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

log "Starting EKS node bootstrap process for AL2023"

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

log "Instance ID: $INSTANCE_ID, Region: $REGION, Cluster: $CLUSTER_NAME"

# Check if this is AL2023 and use nodeadm
if command -v nodeadm &> /dev/null; then
    log "Using nodeadm for AL2023 EKS AMI"
    
    # Create nodeadm configuration
    cat > /tmp/nodeadm-config.yaml <<EOF
---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: $CLUSTER_NAME
    apiServerEndpoint: $CLUSTER_ENDPOINT
    certificateAuthority: $CLUSTER_CA_DATA
  kubelet:
    config:
      clusterDomain: cluster.local
      maxPods: 110
    flags:
      - --node-labels=node.kubernetes.io/instance-type=\$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
EOF

    # Add bootstrap arguments if provided
    if [ ! -z "$BOOTSTRAP_ARGUMENTS" ]; then
        log "Adding bootstrap arguments: $BOOTSTRAP_ARGUMENTS"
        echo "      - $BOOTSTRAP_ARGUMENTS" >> /tmp/nodeadm-config.yaml
    fi

    # Initialize the node using nodeadm
    log "Initializing node with nodeadm"
    /usr/bin/nodeadm init /tmp/nodeadm-config.yaml
    
    if [ $? -eq 0 ]; then
        log "nodeadm initialization completed successfully"
    else
        log "ERROR: nodeadm initialization failed"
        exit 1
    fi

elif [ -f /etc/eks/bootstrap.sh ]; then
    log "Using legacy EKS bootstrap script"
    /etc/eks/bootstrap.sh $CLUSTER_NAME $BOOTSTRAP_ARGUMENTS
    
else
    log "ERROR: Neither nodeadm nor bootstrap.sh found. This AMI may not be EKS-optimized."
    exit 1
fi

# Verify kubelet is running
log "Verifying kubelet status"
systemctl status kubelet --no-pager

# Wait for node to be ready
log "Waiting for node to join cluster..."
for i in {1..30}; do
    if kubectl --kubeconfig /var/lib/kubelet/kubeconfig get nodes | grep -q $(hostname); then
        log "Node successfully joined the cluster"
        break
    fi
    log "Waiting for node to appear in cluster... (attempt $i/30)"
    sleep 10
done

log "Node bootstrap completed. Instance $INSTANCE_ID should now be part of cluster $CLUSTER_NAME"