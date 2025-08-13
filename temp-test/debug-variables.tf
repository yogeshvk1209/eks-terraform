# Debug outputs to verify variables are being read correctly

output "debug_variables" {
  value = {
    managed_node_ami_type = var.managed_node_ami_type
    managed_node_ami_id   = var.managed_node_ami_id
    kubernetes_version    = var.kubernetes_version
    enable_self_managed   = var.enable_self_managed_node_groups
    
    # Check what the EKS module will receive
    eks_defaults = {
      ami_type = var.managed_node_ami_type
      instance_types = ["t4g.medium", "t4g.small"]
    }
    
    # Check self-managed config
    self_managed_config = var.self_managed_node_groups
  }
}