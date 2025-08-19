module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.37.1"
  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version
  subnet_ids      = module.vpc.private_subnets
  
  # Endpoint access configuration for self-managed nodes
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  
  enable_cluster_creator_admin_permissions = true
  
  # Authentication mode for self-managed nodes
  authentication_mode = "API_AND_CONFIG_MAP"

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
  vpc_id = module.vpc.vpc_id

################################################
######## Self Managed Node Groups ##############
################################################
self_managed_node_groups = {
    app_test = {
      ami_type      = "AL2023_x86_64_STANDARD"
      ami_id         = "ami-0fa03f713b55841a2"
      instance_type  = "t3.medium"

      min_size = 1
      max_size = 2
      # This value is ignored after the initial creation
      # https://github.com/bryantbiggs/eks-desired-size-hack
      desired_size = 1

      # This is not required - demonstrates how to pass additional configuration to nodeadm
      # Ref https://awslabs.github.io/amazon-eks-ami/nodeadm/doc/api/
#      cloudinit_pre_nodeadm = [
#        {
#          content_type = "application/node.eks.aws"
#          content      = <<-EOT
#            ---
#            apiVersion: node.eks.aws/v1alpha1
#            kind: NodeConfig
#            spec:
#              cluster:
#                name: local.cluster_name
#                apiServerEndpoint: module.eks.cluster_endpoint
#                certificateAuthority: module.eks.cluster_certificate_authority_data
#              kubelet:
#                config:
#                  shutdownGracePeriod: 30s
#          EOT
#        }
#      ]
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
