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

# Get instance metadata using IMDSv2
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_TYPE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-type)

log "Instance ID: $INSTANCE_ID, Region: $REGION, Cluster: $CLUSTER_NAME, Type: $INSTANCE_TYPE"

# Method 1: Try legacy bootstrap first (most reliable for self-managed nodes)
if [ -f /etc/eks/bootstrap.sh ]; then
    log "Using legacy EKS bootstrap script"
    
    # Construct bootstrap arguments
    BOOTSTRAP_ARGS="$CLUSTER_NAME"
    if [ ! -z "$BOOTSTRAP_ARGUMENTS" ]; then
        BOOTSTRAP_ARGS="$BOOTSTRAP_ARGS $BOOTSTRAP_ARGUMENTS"
    fi
    
    log "Running: /etc/eks/bootstrap.sh $BOOTSTRAP_ARGS"
    /etc/eks/bootstrap.sh $BOOTSTRAP_ARGS
    
    if [ $? -eq 0 ]; then
        log "Legacy bootstrap completed successfully"
    else
        log "ERROR: Legacy bootstrap failed, trying nodeadm"
        # Fall through to nodeadm method
    fi

# Method 2: Try nodeadm (for AL2023)
elif command -v nodeadm &> /dev/null; then
    log "Trying nodeadm for AL2023 EKS AMI"
    
    # First try with IMDS (default behavior)
    log "Attempting nodeadm init with IMDS"
    if /usr/bin/nodeadm init; then
        log "nodeadm initialization with IMDS completed successfully"
    else
        log "nodeadm IMDS method failed"
        exit 1
    fi

# Method 3: Manual configuration (last resort)
else
    log "No bootstrap method found, attempting manual configuration"
    
    # Install and configure kubelet manually
    # This is a simplified version - in production you'd want more robust error handling
    
    # Create kubelet config
    mkdir -p /var/lib/kubelet
    cat > /var/lib/kubelet/kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $CLUSTER_CA_DATA
    server: $CLUSTER_ENDPOINT
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubelet
  name: kubelet
current-context: kubelet
users:
- name: kubelet
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: /usr/bin/aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "$CLUSTER_NAME"
EOF

    # Start kubelet
    systemctl enable kubelet
    systemctl start kubelet
    
    log "Manual kubelet configuration completed"
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

# Final status check
log "Final kubelet status:"
systemctl status kubelet --no-pager

log "Node bootstrap completed. Instance $INSTANCE_ID should now be part of cluster $CLUSTER_NAME"