module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.37.1"
  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version
  subnet_ids      = module.vpc.private_subnets
  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  # Disable add-ons initially - they will be installed after nodes are ready
  # cluster_addons = {
  #   coredns                = {
  #     version  =  var.coredns_version
  #   }
  #   vpc-cni                = {
  #     version  =  var.vpc_cni_version
  #   }
  # }

  enable_irsa = true

  tags = {
    cluster = "app_test"
  }

  vpc_id = module.vpc.vpc_id

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
