#!/bin/bash

# Quick node join troubleshooting script
CLUSTER_NAME="$1"

echo "🔍 EKS Node Join Troubleshooting"
echo "================================"

if [ -z "$CLUSTER_NAME" ]; then
    echo "Usage: $0 <cluster-name>"
    exit 1
fi

# Get instance metadata
if curl -s --max-time 2 http://169.254.169.254/latest/meta-data/ > /dev/null; then
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
    INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
    REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)
    echo "Instance: $INSTANCE_ID in $REGION"
else
    echo "❌ Cannot access instance metadata"
    exit 1
fi

echo ""
echo "1️⃣ Checking kubelet status..."
if systemctl is-active --quiet kubelet; then
    echo "✅ Kubelet is running"
else
    echo "❌ Kubelet is not running"
    echo "   Try: sudo systemctl start kubelet"
    exit 1
fi

echo ""
echo "2️⃣ Checking kubelet logs for common issues..."
RECENT_ERRORS=$(journalctl -u kubelet --since "5 minutes ago" --no-pager | grep -i "error\|failed\|denied" | tail -3)
if [ ! -z "$RECENT_ERRORS" ]; then
    echo "⚠️  Recent kubelet errors found:"
    echo "$RECENT_ERRORS"
else
    echo "✅ No recent kubelet errors"
fi

echo ""
echo "3️⃣ Checking API server connectivity..."
if command -v aws &> /dev/null; then
    CLUSTER_ENDPOINT=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.endpoint' --output text 2>/dev/null)
    if [ ! -z "$CLUSTER_ENDPOINT" ] && [ "$CLUSTER_ENDPOINT" != "None" ]; then
        if curl -k -s --connect-timeout 10 "$CLUSTER_ENDPOINT/healthz" > /dev/null; then
            echo "✅ Can reach EKS API server: $CLUSTER_ENDPOINT"
        else
            echo "❌ Cannot reach EKS API server: $CLUSTER_ENDPOINT"
            echo "   Check security groups and network connectivity"
        fi
    else
        echo "❌ Cannot get cluster endpoint"
    fi
else
    echo "⚠️  AWS CLI not available"
fi

echo ""
echo "4️⃣ Checking node certificates..."
if [ -f /var/lib/kubelet/pki/kubelet-client-current.pem ]; then
    echo "✅ Kubelet client certificate exists"
    
    # Check certificate expiry
    CERT_EXPIRY=$(openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ ! -z "$CERT_EXPIRY" ]; then
        echo "   Certificate expires: $CERT_EXPIRY"
    fi
else
    echo "❌ Kubelet client certificate missing"
    echo "   This might indicate authentication issues"
fi

echo ""
echo "5️⃣ Checking IAM permissions..."
if command -v aws &> /dev/null; then
    # Test basic AWS API access
    if aws sts get-caller-identity --region "$REGION" > /dev/null 2>&1; then
        echo "✅ AWS API access working"
        
        # Check if instance can describe the cluster
        if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" > /dev/null 2>&1; then
            echo "✅ Can access EKS cluster via API"
        else
            echo "❌ Cannot access EKS cluster via API"
            echo "   Check IAM permissions for eks:DescribeCluster"
        fi
    else
        echo "❌ AWS API access failed"
        echo "   Check IAM role attached to instance"
    fi
fi

echo ""
echo "6️⃣ Checking if node appears in cluster..."
if [ -f /var/lib/kubelet/kubeconfig ]; then
    HOSTNAME=$(hostname -s)
    NODE_STATUS=$(kubectl --kubeconfig /var/lib/kubelet/kubeconfig get nodes --no-headers 2>/dev/null | grep "$HOSTNAME" || echo "")
    
    if [ ! -z "$NODE_STATUS" ]; then
        echo "✅ Node found in cluster:"
        echo "   $NODE_STATUS"
    else
        echo "❌ Node not found in cluster"
        echo "   Hostname: $HOSTNAME"
        
        # Try to get all nodes to see if there's a naming issue
        ALL_NODES=$(kubectl --kubeconfig /var/lib/kubelet/kubeconfig get nodes --no-headers 2>/dev/null | awk '{print $1}' || echo "")
        if [ ! -z "$ALL_NODES" ]; then
            echo "   Existing nodes in cluster:"
            echo "$ALL_NODES" | sed 's/^/     /'
        fi
    fi
else
    echo "❌ Kubelet kubeconfig not found"
fi

echo ""
echo "7️⃣ Common solutions:"
echo "   • Restart kubelet: sudo systemctl restart kubelet"
echo "   • Check security groups allow traffic on ports 443, 10250"
echo "   • Verify IAM role has required EKS permissions"
echo "   • Check if cluster endpoint is accessible from subnet"
echo "   • Ensure instance is in correct VPC/subnets"
echo ""
echo "📋 For detailed logs, run:"
echo "   sudo journalctl -u kubelet -f"
echo "   ./scripts/utils/collect-logs.sh $CLUSTER_NAME"