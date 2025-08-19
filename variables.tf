variable "kubernetes_version" {
  default     = 1.32
  description = "kubernetes version"
}

variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  description = "default CIDR range of the VPC"
}
variable "aws_region" {
  default = "us-east-1"
  description = "aws region"
}

variable "node_eks_version" {
  description = "Kubernetes version for the EKS cluster and node groups"
  type        = string
  default     = "1.33"
}

variable "coredns_version" {
  description = "CoreDNS add-on version"
  type        = string
  default     = "v1.11.1-eksbuild.4"
}

variable "vpc_cni_version" {
  description = "VPC CNI add-on version"
  type        = string
  default     = "v1.18.1-eksbuild.2"
}

# Managed node group AMI configuration
variable "managed_node_ami_type" {
  description = "AMI type for managed node groups"
  type        = string
  default     = "AL2023_ARM_64_STANDARD"
  
  validation {
    condition = contains([
      "AL2023_x86_64_STANDARD",
      "AL2023_ARM_64_STANDARD", 
      "AL2_x86_64",
      "AL2_ARM_64",
      "BOTTLEROCKET_ARM_64",
      "BOTTLEROCKET_x86_64",
      "WINDOWS_CORE_2019_x86_64",
      "WINDOWS_FULL_2019_x86_64",
      "WINDOWS_CORE_2022_x86_64",
      "WINDOWS_FULL_2022_x86_64"
    ], var.managed_node_ami_type)
    error_message = "AMI type must be a valid EKS managed node group AMI type."
  }
}

variable "managed_node_ami_id" {
  description = "Specific AMI ID for managed node groups (overrides ami_type if provided)"
  type        = string
  default     = ""
}

# EKS Add-ons configuration
variable "install_eks_addons" {
  description = "Whether to install EKS add-ons (CoreDNS, VPC CNI, EBS CSI)"
  type        = bool
  default     = true
}

# Self-managed node group variables
variable "enable_self_managed_node_groups" {
  description = "Whether to create self-managed node groups"
  type        = bool
  default     = false
}

variable "use_public_subnets_for_nodes" {
  description = "Whether to place self-managed nodes in public subnets (for debugging)"
  type        = bool
  default     = false
}

variable "self_managed_node_groups" {
  description = "Map of self-managed node group configurations"
  type = map(object({
    ami_id                    = optional(string, "")
    instance_types           = optional(list(string), ["t3.medium"])
    min_size                 = optional(number, 1)
    max_size                 = optional(number, 3)
    desired_size             = optional(number, 2)
    capacity_type            = optional(string, "ON_DEMAND")
    subnet_ids               = optional(list(string), [])
    security_group_ids       = optional(list(string), [])
    bootstrap_arguments      = optional(string, "")
    user_data_template_path  = optional(string, "")
    additional_iam_policies  = optional(list(string), [])
    
    # EBS Configuration
    ebs_optimized = optional(bool, true)
    block_device_mappings = optional(list(object({
      device_name = string
      ebs = object({
        volume_size = number
        volume_type = string
        encrypted   = optional(bool, true)
      })
    })), [{
      device_name = "/dev/xvda"
      ebs = {
        volume_size = 20
        volume_type = "gp3"
        encrypted   = true
      }
    }])
    
    # Mixed instances policy for cost optimization
    mixed_instances_policy = optional(object({
      instances_distribution = optional(object({
        on_demand_allocation_strategy            = optional(string, "prioritized")
        on_demand_base_capacity                  = optional(number, 0)
        on_demand_percentage_above_base_capacity = optional(number, 100)
        spot_allocation_strategy                 = optional(string, "lowest-price")
        spot_instance_pools                      = optional(number, 2)
        spot_max_price                          = optional(string, "")
      }), {})
      override = optional(list(object({
        instance_type     = string
        weighted_capacity = optional(string, "1")
      })), [])
    }), null)
    
    # Tagging
    tags = optional(map(string), {})
  }))
  default = {}
  
  validation {
    condition = alltrue([
      for k, v in var.self_managed_node_groups : contains(["ON_DEMAND", "SPOT"], v.capacity_type)
    ])
    error_message = "Capacity type must be either 'ON_DEMAND' or 'SPOT'."
  }
  
  validation {
    condition = alltrue([
      for k, v in var.self_managed_node_groups : v.min_size <= v.desired_size && v.desired_size <= v.max_size
    ])
    error_message = "min_size must be <= desired_size <= max_size for all node groups."
  }
  
  validation {
    condition = alltrue([
      for k, v in var.self_managed_node_groups : v.min_size >= 0 && v.max_size >= 1 && v.desired_size >= 0
    ])
    error_message = "Scaling values must be non-negative, and max_size must be at least 1."
  }
  
  validation {
    condition = alltrue([
      for k, v in var.self_managed_node_groups : length(v.instance_types) > 0
    ])
    error_message = "At least one instance type must be specified for each node group."
  }
  
  validation {
    condition = alltrue([
      for k, v in var.self_managed_node_groups : alltrue([
        for device in v.block_device_mappings : device.ebs.volume_size > 0 && device.ebs.volume_size <= 16384
      ])
    ])
    error_message = "EBS volume size must be between 1 and 16384 GB."
  }
  
  validation {
    condition = alltrue([
      for k, v in var.self_managed_node_groups : alltrue([
        for device in v.block_device_mappings : contains(["gp2", "gp3", "io1", "io2", "sc1", "st1"], device.ebs.volume_type)
      ])
    ])
    error_message = "EBS volume type must be one of: gp2, gp3, io1, io2, sc1, st1."
  }
}
