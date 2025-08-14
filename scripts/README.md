# Scripts Directory

This directory contains various scripts used by the EKS Terraform infrastructure.

## Directory Structure

```
scripts/
├── user-data/          # Bootstrap scripts for EKS nodes
├── utils/              # Utility scripts for deployment and management
└── README.md           # This file
```

## User Data Scripts (`user-data/`)

Bootstrap scripts for EKS worker nodes:

- **`bootstrap-compact.sh`** - *(Active)* Compact universal bootstrap script under 16KB AWS limit
- **`bootstrap.sh`** - *(Reference)* Full-featured bootstrap script with extensive debugging (too large for user-data)

### Usage

The compact bootstrap script is automatically used by Terraform when creating self-managed node groups. It's referenced in `self-managed-nodes.tf`:

```hcl
templatefile("${path.module}/scripts/user-data/bootstrap-compact.sh", {
  cluster_name        = local.cluster_name
  cluster_endpoint    = module.eks.cluster_endpoint
  cluster_ca_data     = module.eks.cluster_certificate_authority_data
  bootstrap_arguments = v.bootstrap_arguments
})
```

### Features

The bootstrap script supports:
- **IMDSv2** - Secure instance metadata access
- **AL2 and AL2023** - Compatible with both Amazon Linux versions
- **ARM64 and x86_64** - Multi-architecture support
- **Multiple fallback methods** - Legacy bootstrap → nodeadm → manual kubelet setup
- **Comprehensive logging** - Detailed bootstrap process logging
- **Error handling** - Robust error handling and recovery

## Utility Scripts (`utils/`)

Management and deployment utilities:

- **`monitor_and_destroy.sh`** - Monitors Terraform apply and auto-destroys on failure
- **`force-cleanup.sh`** - Force cleanup of stuck EKS resources
- **`test-imdsv2.sh`** - Test script to verify IMDSv2 functionality
- **`test-yaml-config.sh`** - Test nodeadm YAML configuration syntax
- **`debug-bootstrap.sh`** - Debug EKS bootstrap issues and system information
- **`collect-logs.sh`** - Comprehensive log collection for troubleshooting
- **`check-node-join.sh`** - Quick troubleshooting for nodes that don't join cluster
- **`fix-kubelet-certs.sh`** - Fix kubelet certificate issues and regenerate certificates
- **`debug-nodeadm.sh`** - Debug nodeadm-specific issues and configuration

### Usage Examples

```bash
# Monitor deployment with auto-cleanup on failure
./scripts/utils/monitor_and_destroy.sh

# Force cleanup stuck resources
./scripts/utils/force-cleanup.sh

# Test IMDSv2 (run on EC2 instance)
./scripts/utils/test-imdsv2.sh

# Test nodeadm YAML configuration
./scripts/utils/test-yaml-config.sh

# Debug bootstrap issues (run on EC2 instance)
./scripts/utils/debug-bootstrap.sh [cluster-name]

# Collect comprehensive logs for troubleshooting
./scripts/utils/collect-logs.sh [cluster-name]

# Quick node join troubleshooting
./scripts/utils/check-node-join.sh <cluster-name>

# Fix kubelet certificate issues
./scripts/utils/fix-kubelet-certs.sh <cluster-name>

# Debug nodeadm issues (AL2023 specific)
./scripts/utils/debug-nodeadm.sh
```

## Best Practices

1. **Always test scripts** in a development environment first
2. **Review logs** in `/var/log/eks-bootstrap.log` on instances
3. **Use IMDSv2** for security compliance
4. **Keep scripts updated** with latest EKS best practices