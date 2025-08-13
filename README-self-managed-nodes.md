# Self-Managed Node Groups for EKS

This document explains how to use the self-managed node groups feature added to the EKS Terraform configuration.

## Overview

Self-managed node groups provide greater control over the underlying EC2 instances compared to EKS managed node groups. This implementation allows you to:

- Use custom AMIs
- Configure advanced networking and storage options
- Implement cost optimization with spot instances
- Have granular control over node lifecycle management
- Run both managed and self-managed node groups simultaneously

## Key Differences: Managed vs Self-Managed Node Groups

| Feature | Managed Node Groups | Self-Managed Node Groups |
|---------|-------------------|-------------------------|
| **Management** | Fully managed by AWS | You manage the EC2 instances |
| **AMI Control** | Limited to EKS-optimized AMIs | Full control over AMI selection |
| **Instance Types** | AWS manages instance selection | Full control over instance types |
| **Spot Instances** | Limited spot support | Advanced spot configuration |
| **Custom User Data** | Limited customization | Full user data control |
| **Scaling** | AWS handles scaling | You configure Auto Scaling Groups |
| **Updates** | Automated updates available | Manual update management |
| **Cost** | Higher cost, easier management | Lower cost, more complexity |

## Configuration

### Basic Setup

1. **Enable self-managed node groups:**
```hcl
enable_self_managed_node_groups = true
```

2. **Configure node groups:**
```hcl
self_managed_node_groups = {
  my-nodes = {
    instance_types = ["t4g.medium"]
    min_size      = 1
    max_size      = 3
    desired_size  = 2
    capacity_type = "ON_DEMAND"
  }
}
```

### Advanced Configuration Options

#### Custom AMI
```hcl
self_managed_node_groups = {
  custom-nodes = {
    ami_id = "ami-0123456789abcdef0"  # Your custom AMI
    # ... other configuration
  }
}
```

#### Spot Instances for Cost Optimization
```hcl
self_managed_node_groups = {
  spot-nodes = {
    instance_types = ["t4g.medium", "t4g.large"]
    capacity_type  = "SPOT"
    mixed_instances_policy = {
      instances_distribution = {
        spot_allocation_strategy = "diversified"
        spot_max_price          = "0.05"
      }
    }
  }
}
```

#### Custom Storage Configuration
```hcl
self_managed_node_groups = {
  storage-nodes = {
    block_device_mappings = [{
      device_name = "/dev/xvda"
      ebs = {
        volume_size = 100
        volume_type = "gp3"
        encrypted   = true
      }
    }]
  }
}
```

#### Additional IAM Policies
```hcl
self_managed_node_groups = {
  privileged-nodes = {
    additional_iam_policies = [
      "arn:aws:iam::aws:policy/AmazonS3FullAccess",
      "arn:aws:iam::aws:policy/CloudWatchFullAccess"
    ]
  }
}
```

## Variable Reference

### Required Variables

- `enable_self_managed_node_groups` (bool): Enable/disable self-managed node groups
- `self_managed_node_groups` (map): Configuration for each node group

### Node Group Configuration Options

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `ami_id` | string | "" | Custom AMI ID (empty = use latest EKS AMI) |
| `instance_types` | list(string) | ["t3.medium"] | EC2 instance types |
| `min_size` | number | 1 | Minimum number of nodes |
| `max_size` | number | 3 | Maximum number of nodes |
| `desired_size` | number | 2 | Desired number of nodes |
| `capacity_type` | string | "ON_DEMAND" | "ON_DEMAND" or "SPOT" |
| `subnet_ids` | list(string) | [] | Custom subnet IDs (empty = use VPC private subnets) |
| `security_group_ids` | list(string) | [] | Additional security group IDs |
| `bootstrap_arguments` | string | "" | Additional kubelet bootstrap arguments |
| `user_data_template_path` | string | "" | Path to custom user data template |
| `additional_iam_policies` | list(string) | [] | Additional IAM policy ARNs |
| `ebs_optimized` | bool | true | Enable EBS optimization |
| `block_device_mappings` | list(object) | [default config] | EBS volume configuration |
| `mixed_instances_policy` | object | null | Mixed instances policy for cost optimization |
| `tags` | map(string) | {} | Additional tags |

## Deployment

1. **Copy the example configuration:**
```bash
cp terraform.tfvars.example terraform.tfvars
```

2. **Customize your configuration:**
Edit `terraform.tfvars` with your specific requirements.

3. **Plan and apply:**
```bash
terraform plan
terraform apply
```

## Migration Guide

### From Managed to Self-Managed Node Groups

1. **Add self-managed configuration** while keeping existing managed node groups
2. **Test the self-managed nodes** with your workloads
3. **Gradually migrate workloads** from managed to self-managed nodes
4. **Remove managed node groups** once migration is complete

### Example Migration Steps

```hcl
# Step 1: Add self-managed alongside managed
enable_self_managed_node_groups = true
self_managed_node_groups = {
  migration-test = {
    instance_types = ["t4g.medium"]
    min_size      = 1
    max_size      = 2
    desired_size  = 1
  }
}

# Step 2: Scale up self-managed, scale down managed
# (Adjust desired_capacity in managed node groups)

# Step 3: Remove managed node groups configuration
# (Remove eks_managed_node_groups from eks-cluster.tf)
```

## Troubleshooting

### Common Issues

1. **Nodes not joining cluster:**
   - Check IAM permissions
   - Verify security group rules
   - Review user data script logs: `sudo journalctl -u kubelet`

2. **Spot instance interruptions:**
   - Use diverse instance types
   - Implement proper spot interruption handling
   - Monitor spot pricing

3. **Custom AMI issues:**
   - Ensure AMI is EKS-compatible
   - Verify required packages are installed
   - Check user data script compatibility

### Debugging Commands

```bash
# Check node status
kubectl get nodes

# View node logs
kubectl describe node <node-name>

# Check kubelet logs on the node
sudo journalctl -u kubelet -f

# View bootstrap logs
sudo cat /var/log/eks-bootstrap.log
```

## Best Practices

1. **Start with small node groups** and scale gradually
2. **Use multiple instance types** for better availability
3. **Implement proper monitoring** and alerting
4. **Test custom AMIs thoroughly** before production use
5. **Use spot instances wisely** for non-critical workloads
6. **Keep security groups minimal** and well-documented
7. **Tag resources consistently** for cost tracking and management

## Security Considerations

- Self-managed nodes require more security management
- Regularly update AMIs and security patches
- Monitor IAM permissions and access patterns
- Use encrypted EBS volumes
- Implement network security best practices
- Regular security audits and compliance checks

## Cost Optimization

- Use spot instances for development and batch workloads
- Right-size instance types based on actual usage
- Implement cluster autoscaling
- Monitor and optimize EBS storage costs
- Use reserved instances for predictable workloads

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review AWS EKS documentation
3. Check Terraform AWS provider documentation
4. Review CloudWatch logs and metrics