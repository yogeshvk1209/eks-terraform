output "cluster_id" {
  description = "EKS cluster ID."
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane."
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IRSA."
  value       = module.eks.oidc_provider_arn
}

# Node Group Outputs
#output "eks_managed_node_groups" {
#  description = "EKS managed node groups configuration."
#  value       = module.eks.eks_managed_node_groups
#}

#output "eks_managed_node_groups_autoscaling_group_names" {
#  description = "Names of the EKS managed node groups ASGs."
#  value       = module.eks.eks_managed_node_groups_autoscaling_group_names
#}

# VPC Outputs
output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of private subnet IDs."
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs."
  value       = module.vpc.public_subnets
}

# Cluster Access
output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster."
  value       = module.eks.cluster_certificate_authority_data
}

# Cluster Security
output "cluster_primary_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster."
  value       = module.eks.cluster_primary_security_group_id
}

# Node Security Groups
output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes."
  value       = module.eks.node_security_group_id
}

# Access Configuration
output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster."
  value       = module.eks.cluster_arn
}
