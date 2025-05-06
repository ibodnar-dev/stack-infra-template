output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "all_subnet_ids" {
  description = "List of IDs of all subnets (public and private)"
  value       = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.this[*].id
}

output "nat_gateway_public_ips" {
  description = "List of public Elastic IPs created for NAT Gateway"
  value       = aws_eip.nat[*].public_ip
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private.id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}

output "vpc_endpoint_s3_id" {
  description = "ID of S3 VPC endpoint"
  value       = var.create_vpc_endpoints ? aws_vpc_endpoint.s3[0].id : null
}

output "vpc_endpoint_ecr_api_id" {
  description = "ID of ECR API VPC endpoint"
  value       = var.create_vpc_endpoints ? aws_vpc_endpoint.ecr_api[0].id : null
}

output "vpc_endpoint_ecr_dkr_id" {
  description = "ID of ECR Docker VPC endpoint"
  value       = var.create_vpc_endpoints ? aws_vpc_endpoint.ecr_dkr[0].id : null
}

output "vpc_endpoint_logs_id" {
  description = "ID of CloudWatch Logs VPC endpoint"
  value       = var.create_vpc_endpoints ? aws_vpc_endpoint.logs[0].id : null
}

output "vpc_endpoint_sts_id" {
  description = "ID of STS VPC endpoint"
  value       = var.create_vpc_endpoints ? aws_vpc_endpoint.sts[0].id : null
}
