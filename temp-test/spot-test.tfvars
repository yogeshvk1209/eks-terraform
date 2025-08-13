# Spot instance self-managed node group test configuration

enable_self_managed_node_groups = true

self_managed_node_groups = {
  test-spot = {
    instance_types = ["t4g.small", "t4g.medium"]
    min_size      = 0
    max_size      = 3
    desired_size  = 1
    capacity_type = "SPOT"
    
    mixed_instances_policy = {
      instances_distribution = {
        on_demand_base_capacity                  = 0
        on_demand_percentage_above_base_capacity = 0
        spot_allocation_strategy                 = "lowest-price"
        spot_instance_pools                      = 2
        spot_max_price                          = "0.02"
      }
      override = [
        {
          instance_type     = "t4g.small"
          weighted_capacity = "1"
        },
        {
          instance_type     = "t4g.medium"
          weighted_capacity = "2"
        }
      ]
    }
    
    bootstrap_arguments = "--kubelet-extra-args '--node-labels=node.kubernetes.io/lifecycle=spot'"
    
    tags = {
      Test        = "spot"
      Environment = "test"
    }
  }
}