# EKS Add-ons - Installed after self-managed nodes are ready

# CoreDNS Add-on
resource "aws_eks_addon" "coredns" {
  count = var.enable_self_managed_node_groups && var.install_eks_addons ? 1 : 0
  
  cluster_name             = module.eks.cluster_name
  addon_name               = "coredns"
  addon_version            = var.coredns_version
  resolve_conflicts        = "OVERWRITE"
  
  depends_on = [
    aws_autoscaling_group.self_managed_nodes
  ]
  
  tags = {
    Name = "${local.cluster_name}-coredns-addon"
  }
}

# VPC CNI Add-on
resource "aws_eks_addon" "vpc_cni" {
  count = var.enable_self_managed_node_groups && var.install_eks_addons ? 1 : 0
  
  cluster_name             = module.eks.cluster_name
  addon_name               = "vpc-cni"
  addon_version            = var.vpc_cni_version
  resolve_conflicts        = "OVERWRITE"
  
  depends_on = [
    aws_autoscaling_group.self_managed_nodes
  ]
  
  tags = {
    Name = "${local.cluster_name}-vpc-cni-addon"
  }
}

# EBS CSI Driver Add-on (recommended for persistent volumes)
resource "aws_eks_addon" "ebs_csi" {
  count = var.enable_self_managed_node_groups && var.install_eks_addons ? 1 : 0
  
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  resolve_conflicts        = "OVERWRITE"
  
  depends_on = [
    aws_autoscaling_group.self_managed_nodes
  ]
  
  tags = {
    Name = "${local.cluster_name}-ebs-csi-addon"
  }
}