# Custom AMI self-managed node group test configuration

enable_self_managed_node_groups = true

self_managed_node_groups = {
  test-custom-ami = {
    ami_id         = "ami-0123456789abcdef0"  # Replace with actual custom AMI
    instance_types = ["m6g.large"]
    min_size      = 1
    max_size      = 3
    desired_size  = 1
    capacity_type = "ON_DEMAND"
    
    # Additional IAM policies for custom workloads
    additional_iam_policies = [
      "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
      "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    ]
    
    # Larger storage for custom workloads
    block_device_mappings = [{
      device_name = "/dev/xvda"
      ebs = {
        volume_size = 100
        volume_type = "gp3"
        encrypted   = true
      }
    }]
    
    tags = {
      Test        = "custom-ami"
      Environment = "test"
      NodeType    = "custom"
    }
  }
}