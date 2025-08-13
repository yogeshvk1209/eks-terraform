# Basic self-managed node group test configuration

enable_self_managed_node_groups = true

self_managed_node_groups = {
  test-basic = {
    instance_types = ["t4g.small"]
    min_size      = 1
    max_size      = 2
    desired_size  = 1
    capacity_type = "ON_DEMAND"
    
    tags = {
      Test        = "basic"
      Environment = "test"
    }
  }
}