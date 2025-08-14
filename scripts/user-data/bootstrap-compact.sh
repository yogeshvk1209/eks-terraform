#!/bin/bash
set -o xtrace

# Compact EKS Bootstrap Script
CLUSTER_NAME="${cluster_name}"
CLUSTER_ENDPOINT="${cluster_endpoint}"
CLUSTER_CA_DATA="${cluster_ca_data}"
BOOTSTRAP_ARGUMENTS="${bootstrap_arguments}"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/eks-bootstrap.log; }

log "Starting EKS bootstrap for cluster: $CLUSTER_NAME"

# Get metadata using IMDSv2
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_TYPE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-type)

log "Instance: $INSTANCE_ID, Region: $REGION, Type: $INSTANCE_TYPE"

BOOTSTRAP_SUCCESS=false

# Method 1: Legacy bootstrap
if [ -f /etc/eks/bootstrap.sh ]; then
    log "Using legacy bootstrap"
    ARGS=""
    [ ! -z "$BOOTSTRAP_ARGUMENTS" ] && ARGS="$BOOTSTRAP_ARGUMENTS"
    if /etc/eks/bootstrap.sh $CLUSTER_NAME $ARGS; then
        log "Legacy bootstrap successful"
        BOOTSTRAP_SUCCESS=true
    else
        log "Legacy bootstrap failed"
    fi
fi

# Method 2: NodeAdm (AL2023)
if [ "$BOOTSTRAP_SUCCESS" = false ] && command -v nodeadm &> /dev/null; then
    log "Using nodeadm"
    cat > /tmp/nodeadm.yaml <<EOF
---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: $CLUSTER_NAME
    apiServerEndpoint: $CLUSTER_ENDPOINT
    certificateAuthority: $CLUSTER_CA_DATA
  kubelet:
    flags:
      - --node-labels=node.kubernetes.io/instance-type=$INSTANCE_TYPE
EOF
    [ ! -z "$BOOTSTRAP_ARGUMENTS" ] && echo "      - $BOOTSTRAP_ARGUMENTS" >> /tmp/nodeadm.yaml
    
    if /usr/bin/nodeadm init --config-source file:///tmp/nodeadm.yaml; then
        log "NodeAdm successful"
        BOOTSTRAP_SUCCESS=true
    else
        log "NodeAdm failed"
    fi
fi

# Method 3: Manual setup
if [ "$BOOTSTRAP_SUCCESS" = false ]; then
    log "Manual kubelet setup"
    mkdir -p /var/lib/kubelet /etc/kubernetes/pki
    echo "$CLUSTER_CA_DATA" | base64 -d > /etc/kubernetes/pki/ca.crt
    
    cat > /var/lib/kubelet/kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $CLUSTER_CA_DATA
    server: $CLUSTER_ENDPOINT
  name: kubernetes
contexts:
- context: {cluster: kubernetes, user: kubelet}
  name: kubelet
current-context: kubelet
users:
- name: kubelet
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: /usr/bin/aws
      args: [eks, get-token, --cluster-name, $CLUSTER_NAME, --region, $REGION]
EOF

    cat > /var/lib/kubelet/config.yaml <<EOF
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
address: 0.0.0.0
authentication: {anonymous: {enabled: false}, webhook: {enabled: true}, x509: {clientCAFile: /etc/kubernetes/pki/ca.crt}}
authorization: {mode: Webhook}
clusterDomain: cluster.local
clusterDNS: [172.20.0.10]
cgroupDriver: systemd
maxPods: 110
EOF

    systemctl enable kubelet && systemctl start kubelet
    log "Manual setup completed"
    BOOTSTRAP_SUCCESS=true
fi

[ "$BOOTSTRAP_SUCCESS" = false ] && { log "All methods failed"; exit 1; }

# Wait for node to join
log "Waiting for node to join cluster..."
for i in {1..20}; do
    if kubectl --kubeconfig /var/lib/kubelet/kubeconfig get nodes 2>/dev/null | grep -q $(hostname -s); then
        log "Node joined successfully"
        break
    fi
    log "Waiting... ($i/20)"
    sleep 15
done

log "Bootstrap completed for $INSTANCE_ID"