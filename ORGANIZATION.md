# Repository Organization

This document describes the reorganized structure of the EKS Terraform repository.

## New Directory Structure

```
eks-terraform/
├── configs/                           # Configuration files
│   ├── tfvars/                       # Terraform variable files
│   │   ├── deploy.tfvars             # Production deployment config
│   │   ├── terraform.tfvars.example  # Comprehensive example
│   │   ├── managed-nodes-test.tfvars # Quick managed nodes test
│   │   ├── quick-fix.tfvars          # Minimal troubleshooting config
│   │   └── temp-test/                # Test scenario configurations
│   │       ├── basic-test.tfvars
│   │       ├── spot-test.tfvars
│   │       └── ...
│   └── README.md                     # Configuration documentation
├── scripts/                          # Scripts and utilities
│   ├── user-data/                    # Bootstrap scripts for EKS nodes
│   │   ├── user_data_universal.sh    # Universal bootstrap (recommended)
│   │   ├── user_data_simple.sh       # Simple legacy bootstrap
│   │   ├── user_data_fixed.sh        # Enhanced with fallbacks
│   │   └── user_data.sh              # Original script
│   ├── utils/                        # Deployment and management utilities
│   │   ├── monitor_and_destroy.sh    # Auto-cleanup on failure
│   │   ├── force-cleanup.sh          # Force cleanup stuck resources
│   │   └── test-imdsv2.sh           # Test IMDSv2 functionality
│   └── README.md                     # Scripts documentation
├── temp-test/                        # Test configurations and commands
│   └── test-commands.md              # Updated test commands
├── eks-cluster.tf                    # EKS cluster configuration
├── eks-addons.tf                     # EKS add-ons configuration
├── main.tf                           # Provider and backend configuration
├── outputs.tf                        # Output definitions
├── security-groups.tf                # Security group configurations
├── self-managed-nodes.tf             # Self-managed node groups
├── variables.tf                      # Variable definitions
├── vpc.tf                            # VPC configuration
├── README.md                         # Comprehensive documentation (merged)
└── ORGANIZATION.md                   # This file
```

## Changes Made

### 1. Created New Directories
- `configs/tfvars/` - All Terraform variable files
- `scripts/user-data/` - Bootstrap scripts for EKS nodes
- `scripts/utils/` - Utility scripts for deployment and management

### 2. Moved Files
- **User Data Scripts**: `user_data*.sh` → `scripts/user-data/`
- **Terraform Variables**: `*.tfvars` → `configs/tfvars/`
- **Utility Scripts**: `monitor_and_destroy.sh`, `force-cleanup.sh`, `test-imdsv2.sh` → `scripts/utils/`

### 3. Updated References
- **self-managed-nodes.tf**: Updated templatefile path to `scripts/user-data/user_data_universal.sh`
- **README.md**: Updated directory structure and usage examples
- **temp-test/test-commands.md**: Updated tfvars file paths

### 4. Added Documentation
- `configs/README.md` - Configuration files documentation
- `scripts/README.md` - Scripts documentation
- `ORGANIZATION.md` - This organization guide
- **Merged README files** - Combined main README and self-managed nodes documentation

## Usage Examples

### Deploy with Production Config
```bash
terraform apply -var-file=configs/tfvars/deploy.tfvars
```

### Test Different Scenarios
```bash
# Basic self-managed nodes
terraform plan -var-file=configs/tfvars/basic-test.tfvars

# Spot instances
terraform plan -var-file=configs/tfvars/spot-test.tfvars

# Quick managed nodes test
terraform apply -var-file=configs/tfvars/managed-nodes-test.tfvars
```

### Use Utility Scripts
```bash
# Monitor deployment with auto-cleanup
./scripts/utils/monitor_and_destroy.sh

# Force cleanup stuck resources
./scripts/utils/force-cleanup.sh

# Test IMDSv2 (on EC2 instance)
./scripts/utils/test-imdsv2.sh
```

## Benefits of New Organization

1. **Cleaner Root Directory** - Core Terraform files are more visible
2. **Logical Grouping** - Related files are organized together
3. **Better Documentation** - Each directory has its own README
4. **Easier Maintenance** - Scripts and configs are easier to find and update
5. **Scalability** - Easy to add new configurations and scripts

## Migration Notes

- **No Breaking Changes** - All functionality remains the same
- **Updated Paths** - Use new paths in commands and documentation
- **Backward Compatibility** - Old file locations are no longer valid
- **Version Control** - Commit these changes to preserve history

## Best Practices

1. **Use the new paths** in all commands and documentation
2. **Add new tfvars files** to `configs/tfvars/`
3. **Add new scripts** to appropriate subdirectories in `scripts/`
4. **Update documentation** when adding new files
5. **Test configurations** before deploying to production