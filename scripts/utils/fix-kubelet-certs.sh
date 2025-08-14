#!/bin/bash

# Script to fix kubelet certificate issues
CLUSTER_NAME="$1"

echo "🔧 Kubelet Certificate Fix Script"
echo "================================="

if [ -z "$CLUSTER_NAME" ]; then
    echo "Usage: $0 <cluster-name>"
    exit 1
fi

# Get region from metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)

echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo ""

echo "1️⃣ Checking current certificate status..."
if [ -f /var/lib/kubelet/pki/kubelet-client-current.pem ]; then
    echo "✅ kubelet-client-current.pem exists"
    
    # Check certificate details
    CERT_SUBJECT=$(openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -subject 2>/dev/null)
    CERT_EXPIRY=$(openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -enddate 2>/dev/null)
    
    echo "   Subject: $CERT_SUBJECT"
    echo "   Expiry: $CERT_EXPIRY"
elif [ -f /var/lib/kubelet/pki/kubelet-client.crt ]; then
    echo "✅ kubelet-client.crt exists (alternative location)"
else
    echo "❌ No kubelet client certificate found"
    echo ""
    echo "Certificate directories:"
    ls -la /var/lib/kubelet/pki/ 2>/dev/null || echo "No pki directory"
    ls -la /var/lib/kubelet/ 2>/dev/null || echo "No kubelet directory"
fi

echo ""
echo "2️⃣ Checking kubelet configuration..."
if [ -f /var/lib/kubelet/kubeconfig ]; then
    echo "✅ kubelet kubeconfig exists"
    
    # Check if kubeconfig has correct cluster endpoint
    KUBECONFIG_SERVER=$(grep "server:" /var/lib/kubelet/kubeconfig | awk '{print $2}')
    echo "   Server: $KUBECONFIG_SERVER"
    
    # Get actual cluster endpoint
    if command -v aws &> /dev/null; then
        ACTUAL_ENDPOINT=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.endpoint' --output text 2>/dev/null)
        if [ "$KUBECONFIG_SERVER" = "$ACTUAL_ENDPOINT" ]; then
            echo "   ✅ Endpoint matches cluster"
        else
            echo "   ❌ Endpoint mismatch. Expected: $ACTUAL_ENDPOINT"
        fi
    fi
else
    echo "❌ kubelet kubeconfig missing"
fi

echo ""
echo "3️⃣ Checking kubelet service status..."
if systemctl is-active --quiet kubelet; then
    echo "✅ kubelet is running"
else
    echo "❌ kubelet is not running"
fi

echo ""
echo "4️⃣ Attempting certificate regeneration..."

# Stop kubelet
echo "Stopping kubelet..."
systemctl stop kubelet

# Backup existing certificates
if [ -d /var/lib/kubelet/pki ]; then
    echo "Backing up existing certificates..."
    mv /var/lib/kubelet/pki /var/lib/kubelet/pki.backup.$(date +%Y%m%d-%H%M%S)
fi

# Remove old kubeconfig
if [ -f /var/lib/kubelet/kubeconfig ]; then
    echo "Backing up kubeconfig..."
    mv /var/lib/kubelet/kubeconfig /var/lib/kubelet/kubeconfig.backup.$(date +%Y%m%d-%H%M%S)
fi

# Recreate directories
mkdir -p /var/lib/kubelet/pki

# Get cluster information
if command -v aws &> /dev/null; then
    echo "Getting cluster information..."
    CLUSTER_ENDPOINT=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.endpoint' --output text 2>/dev/null)
    CLUSTER_CA_DATA=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.certificateAuthority.data' --output text 2>/dev/null)
    
    if [ ! -z "$CLUSTER_ENDPOINT" ] && [ ! -z "$CLUSTER_CA_DATA" ]; then
        echo "✅ Retrieved cluster information"
        
        # Create new kubeconfig
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
        
        echo "✅ Created new kubeconfig"
    else
        echo "❌ Could not retrieve cluster information"
        exit 1
    fi
else
    echo "❌ AWS CLI not available"
    exit 1
fi

# Set proper permissions
chown -R root:root /var/lib/kubelet/
chmod 600 /var/lib/kubelet/kubeconfig

echo ""
echo "5️⃣ Starting kubelet..."
systemctl start kubelet

# Wait a moment for kubelet to start
sleep 5

if systemctl is-active --quiet kubelet; then
    echo "✅ kubelet started successfully"
    
    # Wait for certificate generation
    echo "Waiting for certificate generation..."
    for i in {1..30}; do
        if [ -f /var/lib/kubelet/pki/kubelet-client-current.pem ] || [ -f /var/lib/kubelet/pki/kubelet-client.crt ]; then
            echo "✅ Certificate generated successfully!"
            break
        fi
        echo "Waiting... ($i/30)"
        sleep 2
    done
    
    # Check final status
    if [ -f /var/lib/kubelet/pki/kubelet-client-current.pem ] || [ -f /var/lib/kubelet/pki/kubelet-client.crt ]; then
        echo ""
        echo "🎉 Certificate fix completed successfully!"
        echo ""
        echo "Certificate files:"
        ls -la /var/lib/kubelet/pki/
        
        echo ""
        echo "Monitor kubelet logs with:"
        echo "sudo journalctl -u kubelet -f"
    else
        echo ""
        echo "❌ Certificate generation failed"
        echo "Check kubelet logs: sudo journalctl -u kubelet -f"
    fi
else
    echo "❌ kubelet failed to start"
    systemctl status kubelet --no-pager
fi