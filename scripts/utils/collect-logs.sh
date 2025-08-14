#!/bin/bash

# Comprehensive log collection script for EKS bootstrap debugging
CLUSTER_NAME="$1"
OUTPUT_DIR="/tmp/eks-debug-$(date +%Y%m%d-%H%M%S)"

echo "🔍 Collecting EKS Bootstrap Debug Logs"
echo "======================================"
echo "Output directory: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

# System Information
echo "📋 Collecting system information..."
{
    echo "=== SYSTEM INFO ==="
    date
    hostname
    whoami
    uptime
    
    echo -e "\n=== OS INFO ==="
    cat /etc/os-release 2>/dev/null || echo "No /etc/os-release"
    
    echo -e "\n=== INSTANCE METADATA ==="
    if curl -s --max-time 2 http://169.254.169.254/latest/meta-data/ > /dev/null; then
        TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
        echo "Instance ID: $(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)"
        echo "Instance Type: $(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-type)"
        echo "Region: $(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)"
        echo "AZ: $(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"
    else
        echo "Cannot access instance metadata"
    fi
} > "$OUTPUT_DIR/system-info.txt"

# Service Status
echo "🔧 Collecting service status..."
{
    echo "=== SERVICE STATUS ==="
    systemctl status kubelet --no-pager --full
    echo -e "\n=== CONTAINERD STATUS ==="
    systemctl status containerd --no-pager --full
    echo -e "\n=== ENABLED SERVICES ==="
    systemctl list-unit-files --state=enabled | grep -E "(kubelet|containerd|docker)"
} > "$OUTPUT_DIR/service-status.txt"

# Log Files
echo "📝 Collecting log files..."

# Bootstrap logs
if [ -f /var/log/eks-bootstrap.log ]; then
    cp /var/log/eks-bootstrap.log "$OUTPUT_DIR/"
    echo "✅ Copied eks-bootstrap.log"
else
    echo "❌ No eks-bootstrap.log found"
fi

# Cloud-init logs
if [ -f /var/log/cloud-init-output.log ]; then
    cp /var/log/cloud-init-output.log "$OUTPUT_DIR/"
    echo "✅ Copied cloud-init-output.log"
fi

if [ -f /var/log/cloud-init.log ]; then
    cp /var/log/cloud-init.log "$OUTPUT_DIR/"
    echo "✅ Copied cloud-init.log"
fi

# Kubelet logs
echo "📋 Collecting kubelet logs..."
journalctl -u kubelet --no-pager --since "30 minutes ago" > "$OUTPUT_DIR/kubelet.log"
journalctl -u kubelet --no-pager --since "30 minutes ago" --grep="error\|failed\|denied" > "$OUTPUT_DIR/kubelet-errors.log"

# Containerd logs
journalctl -u containerd --no-pager --since "30 minutes ago" > "$OUTPUT_DIR/containerd.log"

# Configuration Files
echo "⚙️  Collecting configuration files..."
mkdir -p "$OUTPUT_DIR/configs"

# Kubelet configs
if [ -d /var/lib/kubelet ]; then
    cp -r /var/lib/kubelet "$OUTPUT_DIR/configs/" 2>/dev/null || echo "Could not copy kubelet configs"
fi

# NodeAdm configs
if [ -f /tmp/nodeadm-config.yaml ]; then
    cp /tmp/nodeadm-config.yaml "$OUTPUT_DIR/configs/"
    echo "✅ Copied nodeadm-config.yaml"
fi

# Network Information
echo "🌐 Collecting network information..."
{
    echo "=== NETWORK INTERFACES ==="
    ip addr show
    echo -e "\n=== ROUTING TABLE ==="
    ip route show
    echo -e "\n=== DNS CONFIGURATION ==="
    cat /etc/resolv.conf
    echo -e "\n=== IPTABLES RULES ==="
    iptables -L -n 2>/dev/null || echo "Cannot read iptables"
} > "$OUTPUT_DIR/network-info.txt"

# Process Information
echo "🔄 Collecting process information..."
{
    echo "=== RUNNING PROCESSES ==="
    ps aux | grep -E "(kubelet|containerd|nodeadm|aws)" | grep -v grep
    echo -e "\n=== MEMORY USAGE ==="
    free -h
    echo -e "\n=== DISK USAGE ==="
    df -h
} > "$OUTPUT_DIR/process-info.txt"

# Kubernetes Information
if [ ! -z "$CLUSTER_NAME" ]; then
    echo "☸️  Collecting Kubernetes information..."
    {
        echo "=== CLUSTER INFO ==="
        if command -v aws &> /dev/null; then
            aws eks describe-cluster --name "$CLUSTER_NAME" 2>/dev/null || echo "Cannot describe cluster"
        fi
        
        echo -e "\n=== NODE STATUS (from kubelet kubeconfig) ==="
        if [ -f /var/lib/kubelet/kubeconfig ]; then
            kubectl --kubeconfig /var/lib/kubelet/kubeconfig get nodes 2>/dev/null || echo "Cannot get nodes"
            kubectl --kubeconfig /var/lib/kubelet/kubeconfig get nodes -o wide 2>/dev/null || echo "Cannot get nodes wide"
        fi
        
        echo -e "\n=== PODS IN KUBE-SYSTEM ==="
        if [ -f /var/lib/kubelet/kubeconfig ]; then
            kubectl --kubeconfig /var/lib/kubelet/kubeconfig get pods -n kube-system 2>/dev/null || echo "Cannot get pods"
        fi
    } > "$OUTPUT_DIR/kubernetes-info.txt"
fi

# Connectivity Tests
echo "🔗 Running connectivity tests..."
{
    echo "=== CONNECTIVITY TESTS ==="
    echo "Internet connectivity:"
    ping -c 3 8.8.8.8 2>&1
    
    echo -e "\nCluster endpoint connectivity:"
    if [ ! -z "$CLUSTER_NAME" ] && command -v aws &> /dev/null; then
        CLUSTER_ENDPOINT=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query 'cluster.endpoint' --output text 2>/dev/null)
        if [ ! -z "$CLUSTER_ENDPOINT" ] && [ "$CLUSTER_ENDPOINT" != "None" ]; then
            echo "Testing $CLUSTER_ENDPOINT"
            curl -k -s --connect-timeout 10 "$CLUSTER_ENDPOINT/healthz" && echo "✅ API server reachable" || echo "❌ API server unreachable"
        fi
    fi
    
    echo -e "\nDNS resolution:"
    nslookup kubernetes.default.svc.cluster.local 2>&1 || echo "Cannot resolve cluster DNS"
} > "$OUTPUT_DIR/connectivity-tests.txt"

# Create summary
echo "📊 Creating summary..."
{
    echo "EKS Bootstrap Debug Summary"
    echo "=========================="
    echo "Generated: $(date)"
    echo "Hostname: $(hostname)"
    echo "Cluster: ${CLUSTER_NAME:-'Not specified'}"
    echo ""
    
    echo "Key Status:"
    systemctl is-active kubelet >/dev/null && echo "✅ Kubelet: Running" || echo "❌ Kubelet: Not running"
    systemctl is-active containerd >/dev/null && echo "✅ Containerd: Running" || echo "❌ Containerd: Not running"
    
    if [ -f /var/lib/kubelet/kubeconfig ]; then
        echo "✅ Kubelet kubeconfig: Present"
    else
        echo "❌ Kubelet kubeconfig: Missing"
    fi
    
    echo ""
    echo "Recent Errors:"
    journalctl -u kubelet --since "10 minutes ago" --no-pager | grep -i "error\|failed" | tail -5 || echo "No recent errors found"
    
    echo ""
    echo "Files collected in: $OUTPUT_DIR"
    echo "To view logs: ls -la $OUTPUT_DIR"
} > "$OUTPUT_DIR/SUMMARY.txt"

# Set permissions
chmod -R 644 "$OUTPUT_DIR"/*
chmod 755 "$OUTPUT_DIR"

echo ""
echo "✅ Log collection completed!"
echo "📁 Files saved to: $OUTPUT_DIR"
echo ""
echo "📋 Quick summary:"
cat "$OUTPUT_DIR/SUMMARY.txt"
echo ""
echo "🔍 To analyze:"
echo "  View summary:        cat $OUTPUT_DIR/SUMMARY.txt"
echo "  View bootstrap logs: cat $OUTPUT_DIR/eks-bootstrap.log"
echo "  View kubelet logs:   cat $OUTPUT_DIR/kubelet.log"
echo "  View kubelet errors: cat $OUTPUT_DIR/kubelet-errors.log"
echo "  View all files:      ls -la $OUTPUT_DIR"