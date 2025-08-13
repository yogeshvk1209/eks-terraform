# Configurations Directory

This directory contains Terraform variable files and configuration examples.

## Directory Structure

```
configs/
├── tfvars/             # Terraform variable files
└── README.md           # This file
```

## Terraform Variables (`tfvars/`)

Configuration files for different deployment scenarios:

### Production Configurations
- **`deploy.tfvars`** - Production deployment with self-managed nodes
- **`terraform.tfvars.example`** - Comprehensive example with all options

### Test Configurations
- **`managed-nodes-test.tfvars`** - Quick test with EKS managed nodes
- **`quick-fix.tfvars`** - Minimal config for troubleshooting

### Test Scenarios (`temp-test/`)
- **`basic-test.tfvars`** - Basic self-managed node group
- **`spot-test.tfvars`** - Spot instance configuration
- **`custom-ami-test.tfvars`** - Custom AMI configuration
- **`hybrid-test.tfvars`** - Mixed managed + self-managed nodes
- **`disabled-test.tfvars`** - Disabled self-managed nodes

## Usage

### Deploy with a specific configuration:
```bash
terraform apply -var-file=configs/tfvars/deploy.tfvars
```

### Test different scenarios:
```bash
# Test basic configuration
terraform plan -var-file=configs/tfvars/basic-test.tfvars

# Test spot instances
terraform plan -var-file=configs/tfvars/spot-test.tfvars

# Quick managed nodes test
terraform apply -var-file=configs/tfvars/managed-nodes-test.tfvars
```

## Configuration Examples

### Basic Self-Managed Nodes
```hcl
enable_self_managed_node_groups = true
self_managed_node_groups = {
  general = {
    instance_types = ["t4g.medium"]
    min_size      = 1
    max_size      = 3
    desired_size  = 1
    capacity_type = "ON_DEMAND"
  }
}
```

### Spot Instance Configuration
```hcl
self_managed_node_groups = {
  spot-workers = {
    instance_types = ["t4g.medium", "t4g.large"]
    capacity_type = "SPOT"
    mixed_instances_policy = {
      instances_distribution = {
        spot_allocation_strategy = "diversified"
        spot_max_price = "0.05"
      }
    }
  }
}
```

### Custom AMI Configuration
```hcl
self_managed_node_groups = {
  custom = {
    ami_id = "ami-0123456789abcdef0"
    instance_types = ["m6g.large"]
    additional_iam_policies = [
      "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
    ]
  }
}
```

## Best Practices

1. **Copy example files** and modify for your needs
2. **Use version control** for your tfvars files
3. **Test configurations** with `terraform plan` first
4. **Document custom configurations** for your team
5. **Keep sensitive values** in environment variables or AWS Secrets Manager