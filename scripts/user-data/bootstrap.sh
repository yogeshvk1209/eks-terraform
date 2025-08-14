#!/bin/bash

# EKS Node Bootstrap Script - Universal (AL2 + AL2023)
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

BOOTSTRAP_SUCCESS=false

# Method 1: Try legacy bootstrap script (AL2 and some AL2023)
if [ -f /etc/eks/bootstrap.sh ]; then
    log "Found legacy bootstrap script, attempting to use it"
    
    # Construct bootstrap arguments
    BOOTSTRAP_ARGS=""
    if [ ! -z "$BOOTSTRAP_ARGUMENTS" ]; then
        BOOTSTRAP_ARGS="$BOOTSTRAP_ARGUMENTS"
    fi
    
    log "Running: /etc/eks/bootstrap.sh $CLUSTER_NAME $BOOTSTRAP_ARGS"
    if /etc/eks/bootstrap.sh $CLUSTER_NAME $BOOTSTRAP_ARGS; then
        log "Legacy bootstrap completed successfully"
        BOOTSTRAP_SUCCESS=true
    else
        log "Legacy bootstrap failed (exit code: $?), will try nodeadm"
        log "Legacy bootstrap error details:"
        tail -20 /var/log/eks-bootstrap.log 2>/dev/null || echo "No bootstrap log available"
    fi
else
    log "No legacy bootstrap script found at /etc/eks/bootstrap.sh"
    log "This appears to be AL2023, will try nodeadm"
fi

# Method 2: Try nodeadm if legacy bootstrap failed or doesn't exist
if [ "$BOOTSTRAP_SUCCESS" = false ] && command -v nodeadm &> /dev/null; then
    log "Using nodeadm for AL2023"
    
    # First, try a minimal approach - let nodeadm handle most configuration automatically
    log "Attempting minimal nodeadm configuration"
    
    # Create a very simple config file
    cat > /tmp/nodeadm-simple.yaml <<EOF
---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: $CLUSTER_NAME
    apiServerEndpoint: $CLUSTER_ENDPOINT
    certificateAuthority: $CLUSTER_CA_DATA
EOF
    
    log "Trying simple nodeadm configuration first"
    if /usr/bin/nodeadm init --config-source file:///tmp/nodeadm-simple.yaml; then
        log "nodeadm initialization with simple config completed successfully"
        BOOTSTRAP_SUCCESS=true
    else
        log "Simple nodeadm config failed, trying detailed config"
        
    # Try to get cluster service CIDR from EKS API
    log "Attempting to get cluster service CIDR from EKS API"
    CLUSTER_CIDR=""
    if command -v aws &> /dev/null; then
        CLUSTER_CIDR=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.kubernetesNetworkConfig.serviceIpv4Cidr' --output text 2>/dev/null || echo "")
    fi
    
    # Use default EKS service CIDR if we couldn't get it from API
    if [ -z "$CLUSTER_CIDR" ] || [ "$CLUSTER_CIDR" = "None" ]; then
        CLUSTER_CIDR="172.20.0.0/16"
        log "Using default EKS service CIDR: $CLUSTER_CIDR"
    else
        log "Retrieved cluster service CIDR: $CLUSTER_CIDR"
    fi
    
    # Calculate DNS server IP (first IP in the service CIDR + 10)
    DNS_SERVER="172.20.0.10"  # Default for 172.20.0.0/16
    if [[ "$CLUSTER_CIDR" == "10.100.0.0/16" ]]; then
        DNS_SERVER="10.100.0.10"
    fi
    
    # Create config file with proper CIDR and validate YAML syntax
    log "Creating nodeadm configuration file"
    cat > /tmp/nodeadm-config.yaml <<EOF
---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: $CLUSTER_NAME
    apiServerEndpoint: $CLUSTER_ENDPOINT
    certificateAuthority: $CLUSTER_CA_DATA
    cidr: $CLUSTER_CIDR
  kubelet:
    config:
      clusterDomain: cluster.local
      clusterDNS:
        - $DNS_SERVER
      maxPods: 110
    flags:
      - --node-labels=node.kubernetes.io/instance-type=$INSTANCE_TYPE
EOF

    # Add bootstrap arguments if provided
    if [ ! -z "$BOOTSTRAP_ARGUMENTS" ]; then
        log "Adding bootstrap arguments: $BOOTSTRAP_ARGUMENTS"
        echo "      - $BOOTSTRAP_ARGUMENTS" >> /tmp/nodeadm-config.yaml
    fi
    
    # Validate YAML syntax before using it
    log "Validating nodeadm configuration syntax"
    if command -v python3 &> /dev/null; then
        python3 -c "
import yaml
import sys
try:
    with open('/tmp/nodeadm-config.yaml', 'r') as f:
        yaml.safe_load(f)
    print('YAML syntax is valid')
except yaml.YAMLError as e:
    print(f'YAML syntax error: {e}')
    sys.exit(1)
" 2>/dev/null
        if [ $? -ne 0 ]; then
            log "❌ YAML configuration is invalid, skipping nodeadm"
            log "Config file contents:"
            cat /tmp/nodeadm-config.yaml
        else
            log "✅ YAML configuration is valid"
            
            # Show config for debugging
            log "NodeAdm configuration:"
            cat /tmp/nodeadm-config.yaml
            
            log "Attempting nodeadm init with config file"
            if /usr/bin/nodeadm init --config-source file:///tmp/nodeadm-config.yaml; then
                log "nodeadm initialization with config file completed successfully"
                BOOTSTRAP_SUCCESS=true
            else
                log "nodeadm config file method failed, will try manual kubelet setup"
                log "NodeAdm error details:"
                journalctl -u nodeadm --no-pager --lines=10 2>/dev/null || echo "No nodeadm service logs"
            fi
        fi
    else
        log "Python3 not available for YAML validation, proceeding with nodeadm"
        
        # Show config for debugging
        log "NodeAdm configuration:"
        cat /tmp/nodeadm-config.yaml
        
        log "Attempting nodeadm init with config file"
        if /usr/bin/nodeadm init --config-source file:///tmp/nodeadm-config.yaml; then
            log "nodeadm initialization with config file completed successfully"
            BOOTSTRAP_SUCCESS=true
        else
            log "nodeadm config file method failed, will try manual kubelet setup"
        fi
    fi
    fi
fi

# Method 3: Manual kubelet setup as last resort
if [ "$BOOTSTRAP_SUCCESS" = false ]; then
    log "Setting up kubelet manually"
    
    # Create kubelet config directory
    mkdir -p /var/lib/kubelet/pki
    mkdir -p /etc/kubernetes/pki
    
    # Create CA certificate
    echo "$CLUSTER_CA_DATA" | base64 -d > /etc/kubernetes/pki/ca.crt
    
    # Ensure proper permissions
    chmod 644 /etc/kubernetes/pki/ca.crt
    chown root:root /etc/kubernetes/pki/ca.crt
    
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

    # Ensure containerd is properly configured
    log "Configuring containerd..."
    
    # Create containerd config if it doesn't exist
    if [ ! -f /etc/containerd/config.toml ]; then
        mkdir -p /etc/containerd
        containerd config default > /etc/containerd/config.toml
        
        # Enable systemd cgroup driver
        sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    fi
    
    # Restart containerd to apply config
    systemctl restart containerd
    sleep 2
    
    # Start services
    systemctl daemon-reload
    systemctl enable kubelet
    systemctl start kubelet
    
    log "Manual kubelet setup completed"
    BOOTSTRAP_SUCCESS=true
fi

# Check if any method succeeded
if [ "$BOOTSTRAP_SUCCESS" = false ]; then
    log "ERROR: All bootstrap methods failed"
    exit 1
fi

# Verify kubelet is running
log "Verifying kubelet status"
systemctl status kubelet --no-pager

# Enhanced node joining verification and debugging
log "Verifying node joining process..."

# Ensure containerd is running before checking kubelet
log "Ensuring containerd is running..."
if ! systemctl is-active --quiet containerd; then
    log "Starting containerd..."
    systemctl start containerd
    sleep 3
fi

if systemctl is-active --quiet containerd; then
    log "✅ Containerd is running"
else
    log "❌ Containerd failed to start"
    systemctl status containerd --no-pager
fi

# Check if kubelet is actually running
if ! systemctl is-active --quiet kubelet; then
    log "ERROR: kubelet is not running after bootstrap"
    log "Attempting to start kubelet..."
    systemctl start kubelet
    sleep 5
    
    if systemctl is-active --quiet kubelet; then
        log "✅ Kubelet started successfully"
    else
        log "❌ Kubelet failed to start"
        systemctl status kubelet --no-pager
        exit 1
    fi
fi

# Check kubelet logs for critical errors (filter out known harmless warnings)
log "Checking kubelet logs for critical errors..."
KUBELET_ERRORS=$(journalctl -u kubelet --since "5 minutes ago" --no-pager | grep -i "error\|failed\|denied" | grep -v "RuntimeConfig from runtime service failed" | grep -v "unknown method RuntimeConfig" | tail -5)
if [ ! -z "$KUBELET_ERRORS" ]; then
    log "WARNING: Found critical kubelet errors:"
    echo "$KUBELET_ERRORS" | while read line; do
        log "  $line"
    done
else
    log "✅ No critical kubelet errors found"
fi

# Check for the specific RuntimeConfig warning (informational only)
RUNTIME_CONFIG_WARNINGS=$(journalctl -u kubelet --since "5 minutes ago" --no-pager | grep "RuntimeConfig from runtime service failed" | wc -l)
if [ "$RUNTIME_CONFIG_WARNINGS" -gt 0 ]; then
    log "ℹ️  Found $RUNTIME_CONFIG_WARNINGS RuntimeConfig warnings (these are usually harmless)"
fi

# Check if kubelet can reach the API server
log "Testing API server connectivity..."
if curl -k -s --connect-timeout 10 "$CLUSTER_ENDPOINT/healthz" > /dev/null; then
    log "✅ Can reach EKS API server"
else
    log "❌ Cannot reach EKS API server at $CLUSTER_ENDPOINT"
fi

# Check if node certificates are working
log "Checking node certificates..."
if [ -f /var/lib/kubelet/pki/kubelet-client-current.pem ]; then
    log "✅ Kubelet client certificate exists"
elif [ -f /var/lib/kubelet/pki/kubelet-client.crt ]; then
    log "✅ Kubelet client certificate exists (alternative location)"
else
    log "❌ Kubelet client certificate missing - this indicates authentication issues"
    log "Certificate directories:"
    ls -la /var/lib/kubelet/pki/ 2>/dev/null || log "No pki directory found"
    
    # Try to regenerate certificates if kubelet is running
    if systemctl is-active --quiet kubelet; then
        log "Attempting to restart kubelet to regenerate certificates..."
        systemctl restart kubelet
        sleep 5
        
        if [ -f /var/lib/kubelet/pki/kubelet-client-current.pem ] || [ -f /var/lib/kubelet/pki/kubelet-client.crt ]; then
            log "✅ Certificate regenerated after kubelet restart"
        else
            log "❌ Certificate still missing after restart"
        fi
    fi
fi

# Wait for node to be ready with enhanced logging
log "Waiting for node to join cluster..."
HOSTNAME=$(hostname -s)
log "Looking for node with hostname: $HOSTNAME"

for i in {1..30}; do
    # Try multiple ways to check if node joined
    NODE_CHECK1=""
    NODE_CHECK2=""
    
    # Method 1: Using kubelet kubeconfig
    if [ -f /var/lib/kubelet/kubeconfig ]; then
        NODE_CHECK1=$(kubectl --kubeconfig /var/lib/kubelet/kubeconfig get nodes --no-headers 2>/dev/null | grep "$HOSTNAME" || echo "")
    fi
    
    # Method 2: Using AWS CLI to check from outside
    if command -v aws &> /dev/null; then
        NODE_CHECK2=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$REGION" 2>/dev/null || echo "")
    fi
    
    if [ ! -z "$NODE_CHECK1" ]; then
        log "✅ Node successfully joined the cluster!"
        log "Node details: $NODE_CHECK1"
        break
    elif [ $i -eq 15 ]; then
        # At halfway point, provide detailed debugging
        log "🔍 Node hasn't joined yet. Debugging information:"
        log "Kubelet status:"
        systemctl status kubelet --no-pager --lines=5
        
        log "Recent kubelet logs:"
        journalctl -u kubelet --since "2 minutes ago" --no-pager --lines=10
        
        log "Network connectivity test:"
        ping -c 2 8.8.8.8 > /dev/null && log "✅ Internet connectivity OK" || log "❌ No internet connectivity"
        
        log "DNS resolution test:"
        nslookup "$CLUSTER_ENDPOINT" > /dev/null && log "✅ Can resolve cluster endpoint" || log "❌ Cannot resolve cluster endpoint"
        
        log "Kubelet configuration files:"
        ls -la /var/lib/kubelet/ | head -10
        
        if [ -f /var/lib/kubelet/config.yaml ]; then
            log "Kubelet config preview:"
            head -20 /var/lib/kubelet/config.yaml
        fi
    fi
    
    log "Waiting for node to appear in cluster... (attempt $i/30)"
    sleep 10
done

# Final status check
if systemctl is-active --quiet kubelet; then
    log "✅ Kubelet is running"
else
    log "❌ Kubelet is not running"
fi

# Show final kubelet logs
log "Final kubelet logs (last 10 lines):"
journalctl -u kubelet --no-pager --lines=10

log "Node bootstrap completed. Instance $INSTANCE_ID for cluster $CLUSTER_NAME"
log "If node didn't join, check the debugging information above and run: sudo journalctl -u kubelet -f"