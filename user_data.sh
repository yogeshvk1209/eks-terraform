#!/bin/bash

# EKS Self-Managed Node Bootstrap Script
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

# Update system packages
log "Updating system packages"
yum update -y

# Install required packages
log "Installing required packages"
yum install -y awscli

# Configure kubelet
log "Configuring kubelet"
mkdir -p /etc/kubernetes/kubelet
mkdir -p /var/lib/kubelet

# Create kubelet configuration
cat > /etc/kubernetes/kubelet/kubelet-config.json <<EOF
{
    "kind": "KubeletConfiguration",
    "apiVersion": "kubelet.config.k8s.io/v1beta1",
    "address": "0.0.0.0",
    "authentication": {
        "anonymous": {
            "enabled": false
        },
        "webhook": {
            "cacheTTL": "2m0s",
            "enabled": true
        },
        "x509": {
            "clientCAFile": "/etc/kubernetes/pki/ca.crt"
        }
    },
    "authorization": {
        "mode": "Webhook",
        "webhook": {
            "cacheAuthorizedTTL": "5m0s",
            "cacheUnauthorizedTTL": "30s"
        }
    },
    "clusterDomain": "cluster.local",
    "hairpinMode": "hairpin-veth",
    "readOnlyPort": 0,
    "cgroupDriver": "systemd",
    "cgroupRoot": "/",
    "featureGates": {
        "RotateKubeletServerCertificate": true
    },
    "protectKernelDefaults": true,
    "serializeImagePulls": false,
    "serverTLSBootstrap": true,
    "tlsCipherSuites": [
        "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
        "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
        "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",
        "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
        "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305",
        "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
        "TLS_RSA_WITH_AES_256_GCM_SHA384",
        "TLS_RSA_WITH_AES_128_GCM_SHA256"
    ]
}
EOF

# Create cluster CA certificate
log "Creating cluster CA certificate"
mkdir -p /etc/kubernetes/pki
echo "$CLUSTER_CA_DATA" | base64 -d > /etc/kubernetes/pki/ca.crt

# Get instance metadata
log "Retrieving instance metadata"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
MAC=$(curl -s http://169.254.169.254/latest/meta-data/mac)
VPC_CIDR=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$MAC/vpc-ipv4-cidr-block)

log "Instance ID: $INSTANCE_ID, Region: $REGION, VPC CIDR: $VPC_CIDR"

# Use EKS bootstrap script if available (for EKS-optimized AMIs)
if [ -f /etc/eks/bootstrap.sh ]; then
    log "Using EKS bootstrap script"
    /etc/eks/bootstrap.sh $CLUSTER_NAME $BOOTSTRAP_ARGUMENTS
else
    log "Manual kubelet configuration"
    
    # Create kubelet service file
    cat > /etc/systemd/system/kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/kubelet \\
    --config=/etc/kubernetes/kubelet/kubelet-config.json \\
    --kubeconfig=/var/lib/kubelet/kubeconfig \\
    --container-runtime=remote \\
    --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
    --node-ip=\$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) \\
    --pod-infra-container-image=602401143452.dkr.ecr.$REGION.amazonaws.com/eks/pause:3.5 \\
    --v=2 \\
    $BOOTSTRAP_ARGUMENTS

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Create kubeconfig
    cat > /var/lib/kubelet/kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/pki/ca.crt
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

    # Enable and start kubelet
    systemctl daemon-reload
    systemctl enable kubelet
    systemctl start kubelet
fi

# Configure iptables for EKS
log "Configuring iptables"
iptables -t nat -A PREROUTING -p tcp -d 169.254.169.254 --dport 80 -j DNAT --to-destination 127.0.0.1:51679
iptables -t nat -A OUTPUT -d 169.254.169.254 -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 51679

# Save iptables rules
service iptables save || true

# Signal completion
log "Bootstrap process completed successfully"

# Send signal to CloudFormation if stack exists (optional)
if [ ! -z "$AWS_DEFAULT_REGION" ]; then
    log "Sending success signal to CloudFormation (if applicable)"
fi

log "Node bootstrap completed. Instance $INSTANCE_ID is ready to join cluster $CLUSTER_NAME"