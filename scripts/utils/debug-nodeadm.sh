#!/bin/bash

# Debug script specifically for nodeadm issues
echo "🔍 NodeAdm Debug Information"
echo "============================"

# Check if nodeadm exists
if ! command -v nodeadm &> /dev/null; then
    echo "❌ nodeadm not found - this is not an AL2023 EKS AMI"
    exit 1
fi

echo "✅ nodeadm found: $(which nodeadm)"
echo "Version: $(nodeadm --version 2>/dev/null || echo 'Unknown')"
echo ""

# Check user-data
echo "📋 EC2 User Data Analysis"
echo "========================="
if curl -s --max-time 2 http://169.254.169.254/latest/meta-data/ > /dev/null; then
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
    USER_DATA=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/user-data 2>/dev/null)
    
    if [ ! -z "$USER_DATA" ]; then
        echo "User data exists (first 200 chars):"
        echo "$USER_DATA" | head -c 200
        echo "..."
        echo ""
        
        # Check if user-data looks like a shell script
        if echo "$USER_DATA" | head -1 | grep -q "#!/bin/bash"; then
            echo "⚠️  User data is a shell script - nodeadm IMDS method will fail"
            echo "   NodeAdm expects YAML/JSON configuration in user-data"
        else
            echo "✅ User data appears to be configuration data"
        fi
    else
        echo "❌ No user data found"
    fi
else
    echo "❌ Cannot access instance metadata"
fi

echo ""
echo "📁 NodeAdm Configuration Files"
echo "=============================="

# Check for nodeadm config files
CONFIG_FILES=(
    "/tmp/nodeadm-config.yaml"
    "/tmp/nodeadm-simple.yaml"
    "/opt/aws/eks/nodeadm-config.yaml"
    "/etc/eks/nodeadm/config.yaml"
)

for config_file in "${CONFIG_FILES[@]}"; do
    if [ -f "$config_file" ]; then
        echo "✅ Found: $config_file"
        echo "   Size: $(du -h "$config_file" | cut -f1)"
        echo "   Contents:"
        head -20 "$config_file" | sed 's/^/     /'
        echo ""
        
        # Validate YAML syntax
        if command -v python3 &> /dev/null; then
            python3 -c "
import yaml
import sys
try:
    with open('$config_file', 'r') as f:
        yaml.safe_load(f)
    print('     ✅ YAML syntax is valid')
except yaml.YAMLError as e:
    print(f'     ❌ YAML syntax error: {e}')
" 2>/dev/null
        fi
        echo ""
    else
        echo "❌ Not found: $config_file"
    fi
done

echo ""
echo "🔧 NodeAdm Service Status"
echo "========================="

# Check if nodeadm has a systemd service
if systemctl list-unit-files | grep -q nodeadm; then
    echo "✅ NodeAdm systemd service exists"
    systemctl status nodeadm --no-pager 2>/dev/null || echo "Service not active"
else
    echo "ℹ️  No nodeadm systemd service (this is normal)"
fi

echo ""
echo "📝 NodeAdm Logs"
echo "==============="

# Check for nodeadm logs in various locations
LOG_LOCATIONS=(
    "/var/log/nodeadm.log"
    "/var/log/eks/nodeadm.log"
    "/tmp/nodeadm.log"
)

for log_file in "${LOG_LOCATIONS[@]}"; do
    if [ -f "$log_file" ]; then
        echo "✅ Found log: $log_file"
        echo "   Last 10 lines:"
        tail -10 "$log_file" | sed 's/^/     /'
        echo ""
    fi
done

# Check journalctl for nodeadm logs
echo "Recent nodeadm logs from journalctl:"
journalctl --grep=nodeadm --no-pager --since "30 minutes ago" 2>/dev/null | tail -10 | sed 's/^/   /' || echo "   No nodeadm logs in journalctl"

echo ""
echo "🧪 NodeAdm Test Commands"
echo "========================"

# Test nodeadm help
echo "NodeAdm help output:"
nodeadm --help 2>&1 | head -20 | sed 's/^/   /'

echo ""
echo "🔍 Troubleshooting Suggestions"
echo "=============================="
echo "1. If user-data is a shell script, nodeadm IMDS will fail"
echo "2. Use explicit config file: nodeadm init --config-source file:///path/to/config.yaml"
echo "3. Ensure YAML syntax is valid in config files"
echo "4. Check that cluster endpoint and CA data are correct"
echo "5. Verify network connectivity to EKS API endpoint"
echo ""
echo "Manual test command:"
echo "   nodeadm init --config-source file:///tmp/nodeadm-config.yaml --dry-run"