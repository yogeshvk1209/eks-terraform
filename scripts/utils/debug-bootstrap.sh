#!/bin/bash

# Debug script for EKS bootstrap issues
echo "🔍 EKS Bootstrap Debug Information"
echo "=================================="

# Check if running on EC2
if curl -s --max-time 2 http://169.254.169.254/latest/meta-data/ > /dev/null; then
    echo "✅ Running on EC2 instance"
    
    # Get instance metadata
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
    INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
    INSTANCE_TYPE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-type)
    REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)
    
    echo "Instance ID: $INSTANCE_ID"
    echo "Instance Type: $INSTANCE_TYPE"
    echo "Region: $REGION"
else
    echo "❌ Not running on EC2 instance or metadata service unavailable"
fi

echo ""
echo "🔧 System Information"
echo "===================="

# OS Version
if [ -f /etc/os-release ]; then
    echo "OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    echo "Version ID: $(grep VERSION_ID /etc/os-release | cut -d'"' -f2)"
fi

echo ""
echo "🚀 Bootstrap Tools"
echo "=================="

# Check for bootstrap tools
if [ -f /etc/eks/bootstrap.sh ]; then
    echo "✅ Legacy bootstrap script found: /etc/eks/bootstrap.sh"
else
    echo "❌ Legacy bootstrap script not found"
fi

if command -v nodeadm &> /dev/null; then
    echo "✅ nodeadm found: $(which nodeadm)"
    echo "   Version: $(nodeadm --version 2>/dev/null || echo 'Unknown')"
    
    # Check for nodeadm config files
    if [ -f /tmp/nodeadm-config.yaml ]; then
        echo "   Config file: /tmp/nodeadm-config.yaml exists"
        echo "   Config preview:"
        head -10 /tmp/nodeadm-config.yaml | sed 's/^/     /'
    fi
else
    echo "❌ nodeadm not found"
fi

if command -v kubelet &> /dev/null; then
    echo "✅ kubelet found: $(which kubelet)"
    echo "   Version: $(kubelet --version 2>/dev/null || echo 'Unknown')"
else
    echo "❌ kubelet not found"
fi

echo ""
echo "📋 Service Status"
echo "================="

# Check kubelet status
if systemctl is-active --quiet kubelet; then
    echo "✅ kubelet is running"
else
    echo "❌ kubelet is not running"
fi

if systemctl is-active --quiet containerd; then
    echo "✅ containerd is running"
else
    echo "❌ containerd is not running"
fi

echo ""
echo "📝 Log Files"
echo "============"

# Check for log files
if [ -f /var/log/eks-bootstrap.log ]; then
    echo "✅ Bootstrap log found: /var/log/eks-bootstrap.log"
    echo "   Last 5 lines:"
    tail -5 /var/log/eks-bootstrap.log | sed 's/^/   /'
else
    echo "❌ Bootstrap log not found"
fi

if [ -f /var/log/cloud-init-output.log ]; then
    echo "✅ Cloud-init log found: /var/log/cloud-init-output.log"
    echo "   Size: $(du -h /var/log/cloud-init-output.log | cut -f1)"
else
    echo "❌ Cloud-init log not found"
fi

echo ""
echo "🔗 Network Connectivity"
echo "======================="

# Test EKS API connectivity (if cluster name is available)
if [ -n "$1" ]; then
    CLUSTER_NAME="$1"
    echo "Testing connectivity to EKS cluster: $CLUSTER_NAME"
    
    if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" > /dev/null 2>&1; then
        echo "✅ Can reach EKS API"
    else
        echo "❌ Cannot reach EKS API"
    fi
else
    echo "ℹ️  Provide cluster name as argument to test EKS connectivity"
fi

echo ""
echo "🔍 Troubleshooting Commands"
echo "==========================="
echo "View bootstrap logs:     sudo tail -f /var/log/eks-bootstrap.log"
echo "View cloud-init logs:    sudo tail -f /var/log/cloud-init-output.log"
echo "View kubelet logs:       sudo journalctl -u kubelet -f"
echo "Check kubelet status:    sudo systemctl status kubelet"
echo "Restart kubelet:         sudo systemctl restart kubelet"
echo "Test nodeadm config:     nodeadm init --config-source file:///tmp/nodeadm-config.yaml --dry-run"
echo "View nodeadm config:     cat /tmp/nodeadm-config.yaml"

echo ""
echo "Debug completed! 🎉"