# Outputs for EKS cluster and node groups

# Existing EKS cluster outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

# Self-managed node groups outputs
output "self_managed_node_groups" {
  description = "Self-managed node group details"
  value = var.enable_self_managed_node_groups ? {
    for k, v in aws_autoscaling_group.self_managed_nodes : k => {
      name                    = v.name
      arn                     = v.arn
      min_size               = v.min_size
      max_size               = v.max_size
      desired_capacity       = v.desired_capacity
      launch_template_id     = aws_launch_template.self_managed_nodes[k].id
      launch_template_version = aws_launch_template.self_managed_nodes[k].latest_version
      iam_role_arn           = aws_iam_role.self_managed_nodes[k].arn
      iam_role_name          = aws_iam_role.self_managed_nodes[k].name
      instance_profile_arn   = aws_iam_instance_profile.self_managed_nodes[k].arn
      instance_profile_name  = aws_iam_instance_profile.self_managed_nodes[k].name
      vpc_zone_identifier    = v.vpc_zone_identifier
    }
  } : {}
}

output "self_managed_node_groups_launch_templates" {
  description = "Launch template details for self-managed node groups"
  value = var.enable_self_managed_node_groups ? {
    for k, v in aws_launch_template.self_managed_nodes : k => {
      id            = v.id
      arn           = v.arn
      name          = v.name
      latest_version = v.latest_version
      image_id      = v.image_id
      instance_type = v.instance_type
    }
  } : {}
}

output "self_managed_node_groups_iam_roles" {
  description = "IAM role details for self-managed node groups"
  value = var.enable_self_managed_node_groups ? {
    for k, v in aws_iam_role.self_managed_nodes : k => {
      name = v.name
      arn  = v.arn
    }
  } : {}
}

output "self_managed_node_groups_status" {
  description = "Status information for self-managed node groups"
  value = {
    enabled = var.enable_self_managed_node_groups
    count   = var.enable_self_managed_node_groups ? length(var.self_managed_node_groups) : 0
    node_groups = var.enable_self_managed_node_groups ? keys(var.self_managed_node_groups) : []
  }
}