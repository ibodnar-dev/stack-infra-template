# Configure the AWS Provider
provider "aws" {
  region = var.region
}

# Get available AZs dynamically
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Use the first 3 AZs unless specified otherwise
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  vpc_name           = "${var.project_name}-vpc"
  vpc_cidr           = var.vpc_cidr
  region             = var.region
  cluster_name       = var.cluster_name
  availability_zones = local.azs
  create_nat_gateway = var.create_nat_gateway
  create_vpc_endpoints = var.create_vpc_endpoints

  tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
  })
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  region           = var.region
  cluster_name     = var.cluster_name
  cluster_version  = var.cluster_version

  # Use VPC module outputs
  vpc_id           = module.vpc.vpc_id
  subnet_ids       = module.vpc.private_subnet_ids  # EKS nodes should be in private subnets

  node_groups      = var.node_groups

  tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
  })

  # Ensure the VPC is created before EKS
  depends_on = [module.vpc]
}

# Configure kubernetes provider with EKS cluster details
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}
