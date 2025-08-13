# Example terraform.tfvars for EKS with Self-Managed Node Groups

# Basic EKS configuration
aws_region         = "us-east-1"
kubernetes_version = "1.31"
vpc_cidr          = "10.0.0.0/16"

# EKS add-on versions
node_eks_version   = "1.31"
coredns_version    = "v1.11.1-eksbuild.4"
vpc_cni_version    = "v1.18.1-eksbuild.2"

# Managed node group AMI configuration
#managed_node_ami_type = "AL2023_ARM_64_STANDARD"  # Default AMI type
# managed_node_ami_id = "ami-0123456789abcdef0"   # Uncomment to use specific AMI ID

# Enable self-managed node groups
enable_self_managed_node_groups = true

# Self-managed node group configurations
self_managed_node_groups = {
  # Example 1: Basic on-demand node group
  general = {
    ami_id          = "ami-03248004fb0418d9f"
    instance_types  = ["t4g.medium"]   #If mixed instance policy -> ["t4g.medium", "t4g.large"]
    min_size       = 1
    max_size       = 3
    desired_size   = 1
    capacity_type  = "ON_DEMAND"
    mixed_instances_policy = null
    
    # Custom EBS configuration
    block_device_mappings = [{
      device_name = "/dev/xvda"
      ebs = {
        volume_size = 30
        volume_type = "gp3"
        encrypted   = true
      }
    }]
    
    tags = {
      Environment = "production"
      Team        = "platform"
    }
  }
}
