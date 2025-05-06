output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.eks_cluster.id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.eks_cluster_sg.id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = aws_eks_cluster.eks_cluster.name
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if IRSA is enabled"
  value       = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

output "kubectl_config_command" {
  description = "Command to update kube config file"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.eks_cluster.name}"
}
