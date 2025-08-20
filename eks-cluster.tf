module "eks" {
  source             = "terraform-aws-modules/eks/aws"
  version            = "21.1.0"
  name       = local.cluster_name
  kubernetes_version = var.kubernetes_version
  subnet_ids         = module.vpc.private_subnets
  
  # Endpoint access configuration for self-managed nodes
  endpoint_public_access  = true
  endpoint_private_access = true
  endpoint_public_access_cidrs = ["0.0.0.0/0"]
  
  enable_cluster_creator_admin_permissions = true
  
  # Authentication mode for self-managed nodes
  authentication_mode = "API_AND_CONFIG_MAP"

  # Disable add-ons initially - they will be installed after nodes are ready
   addons = {
    # coredns                = {
    #   version  =  var.coredns_version
    # }
     vpc-cni                = {
       version  =  var.vpc_cni_version
     }
   }

  enable_irsa = true
  vpc_id = module.vpc.vpc_id

################################################
######## Self Managed Node Groups ##############
################################################
self_managed_node_groups = {
#    app_test_1_32 = {
#      #ami_type       = "AL2023_x86_64_STANDARD"
#      ami_type       = "AL2023_ARM_64_STANDARD"
#      ami_id         = "ami-0d0837afd9e105890"
#      instance_type  = "t4g.medium"
#       min_size = 1
#       max_size = 2
#       desired_size = 1
#    }
    app_test_1_33 = {
      #ami_type      = "AL2023_x86_64_STANDARD"
      ami_type      = "AL2023_ARM_64_STANDARD"
      ami_id         = "ami-0c62bf97314751b4d"
      instance_type  = "t4g.medium"
      min_size = 1
      max_size = 2
      desired_size = 1
    }
  }

  tags = local.tags

################################################
######## EKS Managed Node Groups ##############
################################################
#  eks_managed_node_group_defaults = {
#    ami_type               = var.managed_node_ami_type
#    instance_types         = ["t4g.medium","t4g.small"]
#    vpc_security_group_ids = [aws_security_group.app_test_worker_mgmt.id]
#  }
#  eks_managed_node_groups = {
#    node_group1 = {
#      min_size     = 1
#      max_size     = 3
#      desired_size = 1
      #capacity_type = "SPOT"
#      cluster_version = var.node_eks_version
      # Explicitly set AMI type and instance types to ensure compatibility
#      ami_type = var.managed_node_ami_type
#      instance_types = ["t4g.medium", "t4g.small"]  # ARM64 instances for ARM64 AMI
      # Use specific AMI ID if provided, otherwise use ami_type
#      ami_id = var.managed_node_ami_id != "" ? var.managed_node_ami_id : null
#    }
#  }
  
## Cluster Access Entry example
#  access_entries = {
  # One access entry with a policy associated
#    example = {
#      principal_arn = "arn:aws:iam::123456789012:role/something"
#      policy_associations = {
#        example = {
#          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
#          access_scope = {
#            namespaces = ["default"]
#            type       = "namespace"
#          }
#        }
#      }
#    }
#  }
}

# Note: Self-managed nodes will use IRSA and the node IAM role
# The EKS module should automatically configure aws-auth for self-managed nodes
