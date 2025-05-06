variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "eks-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-cluster"
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = []
}

variable "create_nat_gateway" {
  description = "Whether to create a NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "create_vpc_endpoints" {
  description = "Whether to create VPC endpoints for services like ECR, S3, etc."
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
