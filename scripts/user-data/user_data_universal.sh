#!/bin/bash

# Universal EKS Self-Managed Node Bootstrap Script (AL2 + AL2023)
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
INSTANCE_TYPE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-type)

log "Instance ID: $INSTANCE_ID, Region: $REGION, Cluster: $CLUSTER_NAME, Type: $INSTANCE_TYPE"

# Detect AMI type
if [ -f /etc/os-release ]; then
    OS_VERSION=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
    log "Detected OS version: $OS_VERSION"
fi

# Method 1: Try legacy bootstrap script first (AL2 and some AL2023)
if [ -f /etc/eks/bootstrap.sh ]; then
    log "Found legacy bootstrap script, using it"
    
    # Construct bootstrap arguments
    BOOTSTRAP_ARGS=""
    if [ ! -z "$BOOTSTRAP_ARGUMENTS" ]; then
        BOOTSTRAP_ARGS="$BOOTSTRAP_ARGUMENTS"
    fi
    
    log "Running: /etc/eks/bootstrap.sh $CLUSTER_NAME $BOOTSTRAP_ARGS"
    /etc/eks/bootstrap.sh $CLUSTER_NAME $BOOTSTRAP_ARGS
    
    if [ $? -eq 0 ]; then
        log "Legacy bootstrap completed successfully"
    else
        log "Legacy bootstrap failed, trying nodeadm"
    fi

# Method 2: Use nodeadm for AL2023 (without complex config)
elif command -v nodeadm &> /dev/null; then
    log "Using nodeadm for AL2023"
    
    # For AL2023, nodeadm expects cluster info via IMDS user-data
    # Let's try the simplest approach first
    log "Attempting nodeadm init (will use IMDS user-data)"
    
    # Create minimal user-data in the expected location for nodeadm
    mkdir -p /opt/aws/eks
    cat > /opt/aws/eks/nodeadm-config.yaml <<EOF
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: $CLUSTER_NAME
    apiServerEndpoint: $CLUSTER_ENDPOINT
    certificateAuthority: $CLUSTER_CA_DATA
EOF

    # Try nodeadm init
    if /usr/bin/nodeadm init --config-source file:///opt/aws/eks/nodeadm-config.yaml; then
        log "nodeadm initialization completed successfully"
    else
        log "nodeadm failed, trying manual kubelet setup"
        
        # Manual kubelet setup as fallback
        log "Setting up kubelet manually"
        
        # Create kubelet config directory
        mkdir -p /var/lib/kubelet
        mkdir -p /etc/kubernetes
        
        # Create kubeconfig for kubelet
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
      command: /usr/bin/aws
      args:
        - eks
        - get-token
        - --cluster-name
        - $CLUSTER_NAME
        - --region
        - $REGION
EOF

        # Create kubelet config
        cat > /var/lib/kubelet/config.yaml <<EOF
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
address: 0.0.0.0
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
clusterDomain: cluster.local
clusterDNS:
  - 172.20.0.10
hairpinMode: hairpin-veth
readOnlyPort: 0
cgroupDriver: systemd
cgroupRoot: /
runtimeRequestTimeout: 15m
kubeReserved:
  cpu: 70m
  memory: 574Mi
  ephemeral-storage: 1Gi
systemReserved:
  cpu: 70m
  memory: 574Mi
  ephemeral-storage: 1Gi
evictionHard:
  memory.available: 200Mi
  nodefs.available: 10%
  nodefs.inodesFree: 5%
maxPods: 110
EOF

        # Create CA certificate
        mkdir -p /etc/kubernetes/pki
        echo "$CLUSTER_CA_DATA" | base64 -d > /etc/kubernetes/pki/ca.crt
        
        # Create kubelet service
        cat > /etc/systemd/system/kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/bin/kubelet \\
  --config=/var/lib/kubelet/config.yaml \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --container-runtime-endpoint=unix:///run/containerd/containerd.sock \\
  --node-labels=node.kubernetes.io/instance-type=$INSTANCE_TYPE \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

        # Start services
        systemctl daemon-reload
        systemctl enable kubelet
        systemctl start kubelet
        
        log "Manual kubelet setup completed"
    fi

else
    log "ERROR: Neither bootstrap.sh nor nodeadm found. This may not be an EKS-optimized AMI."
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