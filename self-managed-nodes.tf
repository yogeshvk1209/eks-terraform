self_managed_node_groups = {
    example = {
      ami_type      = "AL2023_x86_64_STANDARD"
      instance_type = "t3.medium"

      min_size = 1
      max_size = 2
      # This value is ignored after the initial creation
      # https://github.com/bryantbiggs/eks-desired-size-hack
      desired_size = 1

      # This is not required - demonstrates how to pass additional configuration to nodeadm
      # Ref https://awslabs.github.io/amazon-eks-ami/nodeadm/doc/api/
      #cloudinit_pre_nodeadm = [
      #  {
      #    content_type = "application/node.eks.aws"
      #    content      = <<-EOT
      #      ---
      #      apiVersion: node.eks.aws/v1alpha1
      #      kind: NodeConfig
      #      spec:
      #        kubelet:
      #          config:
      #            shutdownGracePeriod: 30s
      #    EOT
      #  }
      #]
    }
  }

  tags = local.tags
}
