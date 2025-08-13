# Debug AMI data sources to find the correct pattern

# Test different AMI name patterns
data "aws_ami" "debug_eks_133" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-133-v*"]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
  
  most_recent = true
  owners      = ["602401143452"]
}

data "aws_ami" "debug_eks_1_33" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-1.33-v*"]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
  
  most_recent = true
  owners      = ["602401143452"]
}

data "aws_ami" "debug_eks_any" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-*"]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
  
  most_recent = true
  owners      = ["602401143452"]
}

# Output the results
output "debug_ami_results" {
  value = {
    kubernetes_version = var.kubernetes_version
    version_formatted = replace(var.kubernetes_version, ".", "")
    
    ami_133_found = try(data.aws_ami.debug_eks_133.id, "NOT_FOUND")
    ami_1_33_found = try(data.aws_ami.debug_eks_1_33.id, "NOT_FOUND")
    ami_any_found = try(data.aws_ami.debug_eks_any.id, "NOT_FOUND")
    
    ami_133_name = try(data.aws_ami.debug_eks_133.name, "NOT_FOUND")
    ami_1_33_name = try(data.aws_ami.debug_eks_1_33.name, "NOT_FOUND")
    ami_any_name = try(data.aws_ami.debug_eks_any.name, "NOT_FOUND")
  }
}