#!/bin/bash

# Test script to validate nodeadm YAML configuration
echo "Testing nodeadm YAML configuration..."

# Mock variables for testing
CLUSTER_NAME="test-cluster"
CLUSTER_ENDPOINT="https://test.eks.amazonaws.com"
CLUSTER_CA_DATA="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
INSTANCE_TYPE="t4g.medium"
BOOTSTRAP_ARGUMENTS=""

# Create test YAML
cat > /tmp/test-nodeadm-config.yaml <<EOF
---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: $CLUSTER_NAME
    apiServerEndpoint: $CLUSTER_ENDPOINT
    certificateAuthority: $CLUSTER_CA_DATA
    cidr: 172.20.0.0/16
  kubelet:
    config:
      clusterDomain: cluster.local
      clusterDNS:
        - 172.20.0.10
      maxPods: 110
    flags:
      - --node-labels=node.kubernetes.io/instance-type=$INSTANCE_TYPE
EOF

# Test YAML syntax
if command -v python3 &> /dev/null; then
    echo "Testing YAML syntax with Python..."
    python3 -c "
import yaml
import sys
try:
    with open('/tmp/test-nodeadm-config.yaml', 'r') as f:
        yaml.safe_load(f)
    print('✅ YAML syntax is valid')
    sys.exit(0)
except yaml.YAMLError as e:
    print(f'❌ YAML syntax error: {e}')
    sys.exit(1)
except Exception as e:
    print(f'❌ Error: {e}')
    sys.exit(1)
"
elif command -v yq &> /dev/null; then
    echo "Testing YAML syntax with yq..."
    if yq eval '.' /tmp/test-nodeadm-config.yaml > /dev/null; then
        echo "✅ YAML syntax is valid"
    else
        echo "❌ YAML syntax error"
        exit 1
    fi
else
    echo "⚠️  No YAML validator found (python3 or yq), but file created successfully"
    echo "Contents:"
    cat /tmp/test-nodeadm-config.yaml
fi

# Cleanup
rm -f /tmp/test-nodeadm-config.yaml

echo "✅ YAML configuration test completed"