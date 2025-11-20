module "eks" {
  source             = "terraform-aws-modules/eks/aws"
  version            = "21.1.0"
  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version
  subnet_ids         = module.vpc.private_subnets

  # Endpoint access configuration for self-managed nodes
  endpoint_public_access       = true
  endpoint_private_access      = true
  endpoint_public_access_cidrs = ["0.0.0.0/0"]

  enable_cluster_creator_admin_permissions = true

  # Authentication mode for self-managed nodes
  authentication_mode = "API_AND_CONFIG_MAP"

  # Disable add-ons initially - they will be installed after nodes are ready
  addons = {
    vpc-cni = {
      version = var.vpc_cni_version
    }
  }

  enable_irsa = true
  vpc_id      = module.vpc.vpc_id

  ################################################
  ######## Self Managed Node Groups ##############
  ################################################
  self_managed_node_groups = {
    app_test_1_33 = {
      ami_type      = "AL2023_ARM_64_STANDARD"
      ami_id        = var.self_managed_node_group_ami_id
      instance_type = var.self_managed_node_group_instance_type
      min_size      = 1
      max_size      = 2
      desired_size  = 1
    }
  }

  tags = local.tags
}