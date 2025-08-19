provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

locals {
  cluster_name = "apptest-eks-${random_string.suffix.result}"
  tags = {
    cluster    = "app_test"
    Example    = local.cluster_name
  }
}

resource "random_string" "suffix" {
  length  = 4
  special = false
}



terraform {
  required_version = ">= 1.12.0"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.9.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.3"
    }
  }
}
