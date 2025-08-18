# Self-managed node groups resources

# Check if any node group needs default AMI (doesn't have custom ami_id)
locals {
  needs_default_ami = var.enable_self_managed_node_groups ? length([
    for k, v in var.self_managed_node_groups : k if v.ami_id == ""
  ]) > 0 : false
}

# Data source for latest EKS-optimized AMI (only if needed)
data "aws_ami" "eks_worker" {
  count = local.needs_default_ami ? 1 : 0
  
  filter {
    name   = "name"
    values = ["amazon-eks-node-${replace(var.kubernetes_version, ".", "")}-v*"]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
  
  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

# Alternative data source for ARM64 EKS AMI if the above doesn't work (only if needed)
data "aws_ami" "eks_worker_arm64" {
  count = local.needs_default_ami ? 1 : 0
  
  filter {
    name   = "name"
    values = ["amazon-eks-arm64-node-${replace(var.kubernetes_version, ".", "")}-v*"]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
  
  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

# Fallback: Get any EKS optimized AMI for the region (only if needed)
data "aws_ami" "eks_worker_fallback" {
  count = local.needs_default_ami ? 1 : 0
  
  filter {
    name   = "name"
    values = ["amazon-eks-node-*"]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
  
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
  
  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

# Validate custom AMIs if provided
data "aws_ami" "custom_ami" {
  for_each = {
    for k, v in (var.enable_self_managed_node_groups ? var.self_managed_node_groups : {}) : k => v
    if v.ami_id != ""
  }
  
  filter {
    name   = "image-id"
    values = [each.value.ami_id]
  }
  
  owners = ["self", "amazon", "602401143452"]
}

# Local values for AMI selection
locals {
  # Try to get the best available EKS AMI with multiple fallbacks (only if needed)
  default_eks_ami = local.needs_default_ami ? (
    length(data.aws_ami.eks_worker) > 0 && data.aws_ami.eks_worker[0].id != "" ? 
    data.aws_ami.eks_worker[0].id : 
    (length(data.aws_ami.eks_worker_arm64) > 0 && data.aws_ami.eks_worker_arm64[0].id != "" ?
    data.aws_ami.eks_worker_arm64[0].id :
    (length(data.aws_ami.eks_worker_fallback) > 0 ? data.aws_ami.eks_worker_fallback[0].id : ""))
  ) : ""
  
  self_managed_amis = var.enable_self_managed_node_groups ? {
    for k, v in var.self_managed_node_groups : k => (
      v.ami_id != "" ? v.ami_id : local.default_eks_ami
    )
  } : {}
  
  # Auto-generate mixed instances policy for multiple instance types
  self_managed_mixed_policies = var.enable_self_managed_node_groups ? {
    for k, v in var.self_managed_node_groups : k => (
      length(v.instance_types) > 1 || v.capacity_type == "SPOT" || v.mixed_instances_policy != null ? 
      merge(
        {
          instances_distribution = {
            on_demand_allocation_strategy            = "prioritized"
            on_demand_base_capacity                  = v.capacity_type == "SPOT" ? 0 : 1
            on_demand_percentage_above_base_capacity = v.capacity_type == "SPOT" ? 0 : 100
            spot_allocation_strategy                 = "lowest-price"
            spot_instance_pools                      = 2
            spot_max_price                          = ""
          }
          override = [
            for instance_type in v.instance_types : {
              instance_type     = instance_type
              weighted_capacity = "1"
            }
          ]
        },
        v.mixed_instances_policy != null ? v.mixed_instances_policy : {}
      ) : null
    )
  } : {}
}

# Self-managed node groups IAM resources

# IAM role for self-managed worker nodes
resource "aws_iam_role" "self_managed_nodes" {
  for_each = var.enable_self_managed_node_groups ? var.self_managed_node_groups : {}
  
  name = "${local.cluster_name}-self-managed-${each.key}-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = merge(
    {
      Name = "${local.cluster_name}-self-managed-${each.key}-role"
    },
    each.value.tags
  )
}

# Attach required AWS managed policies
resource "aws_iam_role_policy_attachment" "self_managed_nodes_worker_policy" {
  for_each = var.enable_self_managed_node_groups ? var.self_managed_node_groups : {}
  
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.self_managed_nodes[each.key].name
}

resource "aws_iam_role_policy_attachment" "self_managed_nodes_cni_policy" {
  for_each = var.enable_self_managed_node_groups ? var.self_managed_node_groups : {}
  
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.self_managed_nodes[each.key].name
}

resource "aws_iam_role_policy_attachment" "self_managed_nodes_registry_policy" {
  for_each = var.enable_self_managed_node_groups ? var.self_managed_node_groups : {}
  
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.self_managed_nodes[each.key].name
}

# Attach additional custom IAM policies if specified
resource "aws_iam_role_policy_attachment" "self_managed_nodes_additional_policies" {
  for_each = {
    for pair in flatten([
      for ng_key, ng_config in (var.enable_self_managed_node_groups ? var.self_managed_node_groups : {}) : [
        for policy_arn in ng_config.additional_iam_policies : {
          ng_key     = ng_key
          policy_arn = policy_arn
          key        = "${ng_key}-${replace(policy_arn, "/[^a-zA-Z0-9]/", "-")}"
        }
      ]
    ]) : pair.key => pair
  }
  
  policy_arn = each.value.policy_arn
  role       = aws_iam_role.self_managed_nodes[each.value.ng_key].name
}

# IAM instance profile for EC2 instances
resource "aws_iam_instance_profile" "self_managed_nodes" {
  for_each = var.enable_self_managed_node_groups ? var.self_managed_node_groups : {}
  
  name = "${local.cluster_name}-self-managed-${each.key}-profile"
  role = aws_iam_role.self_managed_nodes[each.key].name

  tags = merge(
    {
      Name = "${local.cluster_name}-self-managed-${each.key}-profile"
    },
    each.value.tags
  )
}
# User data for self-managed nodes
locals {
  self_managed_user_data = var.enable_self_managed_node_groups ? {
    for k, v in var.self_managed_node_groups : k => base64encode(
      v.user_data_template_path != "" ? 
      templatefile(v.user_data_template_path, {
        cluster_name        = local.cluster_name
        cluster_endpoint    = module.eks.cluster_endpoint
        cluster_ca_data     = module.eks.cluster_certificate_authority_data
        bootstrap_arguments = v.bootstrap_arguments
      }) :
      templatefile("${path.module}/scripts/user-data/bootstrap-compact.sh", {
        cluster_name        = local.cluster_name
        cluster_endpoint    = module.eks.cluster_endpoint
        cluster_ca_data     = module.eks.cluster_certificate_authority_data
        bootstrap_arguments = v.bootstrap_arguments
      })
    )
  } : {}
}

# Launch template for self-managed nodes
resource "aws_launch_template" "self_managed_nodes" {
  for_each = var.enable_self_managed_node_groups ? var.self_managed_node_groups : {}
  
  name_prefix   = "${local.cluster_name}-self-managed-${each.key}-"
  image_id      = local.self_managed_amis[each.key]
  
  # Use first instance type as default, others will be handled by mixed instances policy
  instance_type = each.value.instance_types[0]
  
  # Don't use vpc_security_group_ids when using network_interfaces
  # vpc_security_group_ids will be specified in network_interfaces block
  
  iam_instance_profile {
    name = aws_iam_instance_profile.self_managed_nodes[each.key].name
  }
  
  user_data = local.self_managed_user_data[each.key]
  
  # EBS configuration
  dynamic "block_device_mappings" {
    for_each = each.value.block_device_mappings
    content {
      device_name = block_device_mappings.value.device_name
      
      ebs {
        volume_size           = block_device_mappings.value.ebs.volume_size
        volume_type           = block_device_mappings.value.ebs.volume_type
        encrypted             = block_device_mappings.value.ebs.encrypted
        delete_on_termination = true
      }
    }
  }
  
  # Network interface configuration
  network_interfaces {
    associate_public_ip_address = var.use_public_subnets_for_nodes
    delete_on_termination       = true
    device_index               = 0
    security_groups = concat(
      [
        module.eks.cluster_security_group_id,
        aws_security_group.app_test_worker_mgmt.id
      ],
      each.value.security_group_ids
    )
  }
  
  # Instance metadata options
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }
  
  # EBS optimization
  ebs_optimized = each.value.ebs_optimized
  
  # Monitoring
  monitoring {
    enabled = true
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = merge(
      {
        Name                     = "${local.cluster_name}-self-managed-${each.key}"
        "kubernetes-cluster"     = local.cluster_name
        "kubernetes-cluster-owned" = "true"
        "NodeGroup"              = each.key
        "NodeType"               = "self-managed"
      },
      each.value.tags
    )
  }
  
  tag_specifications {
    resource_type = "volume"
    tags = merge(
      {
        Name                     = "${local.cluster_name}-self-managed-${each.key}"
        "kubernetes-cluster"     = local.cluster_name
        "kubernetes-cluster-owned" = "true"
        "NodeGroup"              = each.key
        "NodeType"               = "self-managed"
      },
      each.value.tags
    )
  }
  
  tags = merge(
    {
      Name = "${local.cluster_name}-self-managed-${each.key}-lt"
    },
    each.value.tags
  )
  
  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group for self-managed nodes
resource "aws_autoscaling_group" "self_managed_nodes" {
  for_each = var.enable_self_managed_node_groups ? var.self_managed_node_groups : {}
  
  name                = "${local.cluster_name}-self-managed-${each.key}"
  vpc_zone_identifier = length(each.value.subnet_ids) > 0 ? each.value.subnet_ids : (var.use_public_subnets_for_nodes ? module.vpc.public_subnets : module.vpc.private_subnets)
  target_group_arns   = []
  health_check_type   = "EC2"
  health_check_grace_period = 300
  
  min_size         = each.value.min_size
  max_size         = each.value.max_size
  desired_capacity = each.value.desired_size
  
  # Use mixed instances policy if configured, otherwise use launch template
  dynamic "mixed_instances_policy" {
    for_each = local.self_managed_mixed_policies[each.key] != null ? [local.self_managed_mixed_policies[each.key]] : []
    content {
      launch_template {
        launch_template_specification {
          launch_template_id = aws_launch_template.self_managed_nodes[each.key].id
          version            = "$Latest"
        }
        
        dynamic "override" {
          for_each = mixed_instances_policy.value.override
          content {
            instance_type     = override.value.instance_type
            weighted_capacity = override.value.weighted_capacity
          }
        }
      }
      
      dynamic "instances_distribution" {
        for_each = mixed_instances_policy.value.instances_distribution != null ? [mixed_instances_policy.value.instances_distribution] : []
        content {
          on_demand_allocation_strategy            = instances_distribution.value.on_demand_allocation_strategy
          on_demand_base_capacity                  = instances_distribution.value.on_demand_base_capacity
          on_demand_percentage_above_base_capacity = instances_distribution.value.on_demand_percentage_above_base_capacity
          spot_allocation_strategy                 = instances_distribution.value.spot_allocation_strategy
          spot_instance_pools                      = instances_distribution.value.spot_instance_pools
          spot_max_price                          = instances_distribution.value.spot_max_price
        }
      }
    }
  }
  
  # Use launch template directly if no mixed instances policy
  dynamic "launch_template" {
    for_each = local.self_managed_mixed_policies[each.key] == null ? [1] : []
    content {
      id      = aws_launch_template.self_managed_nodes[each.key].id
      version = "$Latest"
    }
  }
  
  # Instance refresh configuration
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
  }
  
  # Required tags for EKS cluster integration
  tag {
    key                 = "Name"
    value               = "${local.cluster_name}-self-managed-${each.key}"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "kubernetes-cluster"
    value               = local.cluster_name
    propagate_at_launch = true
  }
  
  tag {
    key                 = "NodeGroup"
    value               = each.key
    propagate_at_launch = true
  }
  
  tag {
    key                 = "NodeType"
    value               = "self-managed"
    propagate_at_launch = true
  }
  
  # Additional custom tags
  dynamic "tag" {
    for_each = each.value.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  
  # Lifecycle management
  lifecycle {
    create_before_destroy = true
    ignore_changes       = [desired_capacity]
  }
  
  # EKS cluster discovery tag (applied to ASG, not instances)
  tag {
    key                 = "kubernetes.io/cluster/${local.cluster_name}"
    value               = "owned"
    propagate_at_launch = false  # Don't propagate to instances (would cause invalid tag error)
  }
  
  tag {
    key                 = "ASG-Name"
    value               = "${local.cluster_name}-self-managed-${each.key}-asg"
    propagate_at_launch = false
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.self_managed_nodes_worker_policy,
    aws_iam_role_policy_attachment.self_managed_nodes_cni_policy,
    aws_iam_role_policy_attachment.self_managed_nodes_registry_policy,
  ]
}

# Validation to ensure proper configuration
locals {
  # Validate that self-managed node groups don't conflict with managed ones
  validation_checks = var.enable_self_managed_node_groups ? {
    for k, v in var.self_managed_node_groups : k => {
      # Ensure instance types are valid for the region
      valid_instance_types = alltrue([
        for instance_type in v.instance_types : 
        can(regex("^[a-z][0-9][a-z]*\\.[a-z0-9]+$", instance_type))
      ])
      
      # Ensure capacity type is valid
      valid_capacity_type = contains(["ON_DEMAND", "SPOT"], v.capacity_type)
      
      # Ensure scaling parameters are logical
      valid_scaling = v.min_size <= v.desired_size && v.desired_size <= v.max_size
    }
  } : {}
}

# Validation assertions
resource "null_resource" "validate_self_managed_config" {
  for_each = var.enable_self_managed_node_groups ? var.self_managed_node_groups : {}
  
  lifecycle {
    precondition {
      condition = alltrue([
        for instance_type in each.value.instance_types : 
        can(regex("^[a-z][0-9][a-z]*\\.[a-z0-9]+$", instance_type))
      ])
      error_message = "Invalid instance type format in node group '${each.key}'. Instance types must follow AWS naming convention (e.g., t3.medium)."
    }
    
    precondition {
      condition     = contains(["ON_DEMAND", "SPOT"], each.value.capacity_type)
      error_message = "Invalid capacity_type '${each.value.capacity_type}' in node group '${each.key}'. Must be 'ON_DEMAND' or 'SPOT'."
    }
    
    precondition {
      condition     = each.value.min_size <= each.value.desired_size && each.value.desired_size <= each.value.max_size
      error_message = "Invalid scaling configuration in node group '${each.key}'. min_size (${each.value.min_size}) must be <= desired_size (${each.value.desired_size}) <= max_size (${each.value.max_size})."
    }
    
    precondition {
      condition = each.value.ami_id == "" || can(regex("^ami-[a-f0-9]{8,17}$", each.value.ami_id))
      error_message = "Invalid AMI ID format '${each.value.ami_id}' in node group '${each.key}'. AMI ID must start with 'ami-' followed by 8-17 hexadecimal characters."
    }
  }
}

# Additional security group rules for self-managed nodes (if needed)
# These rules ensure proper communication between self-managed nodes and the EKS cluster

# Allow self-managed nodes to communicate with each other
resource "aws_security_group_rule" "self_managed_nodes_internal" {
  count = var.enable_self_managed_node_groups && length(var.self_managed_node_groups) > 0 ? 1 : 0
  
  description              = "Allow self-managed nodes to communicate with each other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app_test_worker_mgmt.id
  security_group_id        = aws_security_group.app_test_worker_mgmt.id
}

# Allow self-managed nodes to receive traffic from EKS cluster security group
resource "aws_security_group_rule" "self_managed_nodes_from_cluster" {
  count = var.enable_self_managed_node_groups && length(var.self_managed_node_groups) > 0 ? 1 : 0
  
  description              = "Allow traffic from EKS cluster to self-managed nodes"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = module.eks.cluster_security_group_id
  security_group_id        = aws_security_group.app_test_worker_mgmt.id
}

# Allow EKS cluster to receive traffic from self-managed nodes
resource "aws_security_group_rule" "cluster_from_self_managed_nodes" {
  count = var.enable_self_managed_node_groups && length(var.self_managed_node_groups) > 0 ? 1 : 0
  
  description              = "Allow traffic from self-managed nodes to EKS cluster"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app_test_worker_mgmt.id
  security_group_id        = module.eks.cluster_security_group_id
}
