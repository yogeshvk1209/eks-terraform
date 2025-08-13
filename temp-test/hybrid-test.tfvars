# Hybrid configuration with both managed and self-managed node groups

enable_self_managed_node_groups = true

self_managed_node_groups = {
  self-managed-general = {
    instance_types = ["t4g.medium"]
    min_size      = 1
    max_size      = 3
    desired_size  = 2
    capacity_type = "ON_DEMAND"
    
    tags = {
      Test        = "hybrid"
      Environment = "test"
      NodeType    = "self-managed"
    }
  }
  
  self-managed-spot = {
    instance_types = ["t4g.small", "t4g.medium"]
    min_size      = 0
    max_size      = 5
    desired_size  = 1
    capacity_type = "SPOT"
    
    bootstrap_arguments = "--kubelet-extra-args '--node-labels=node.kubernetes.io/lifecycle=spot'"
    
    tags = {
      Test        = "hybrid"
      Environment = "test"
      NodeType    = "self-managed-spot"
    }
  }
}

# Note: Managed node groups are configured in eks-cluster.tf
# This test validates that both can coexist