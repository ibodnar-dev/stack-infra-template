# Create EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

# Attach policies to the EKS cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# Create EKS Node Group IAM Role
resource "aws_iam_role" "eks_node_role" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# Attach policies to the node role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

# Security Group for EKS Cluster
resource "aws_security_group" "eks_cluster_sg" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

# EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster_sg.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy_attachment
  ]

  tags = var.tags
}

# EKS Node Group
resource "aws_eks_node_group" "eks_node_group" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = lookup(each.value, "desired_size", 2)
    max_size     = lookup(each.value, "max_size", 4)
    min_size     = lookup(each.value, "min_size", 1)
  }

  instance_types = lookup(each.value, "instance_types", ["t3.medium"])
  disk_size      = lookup(each.value, "disk_size", 20)
  capacity_type  = lookup(each.value, "capacity_type", "ON_DEMAND")

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy_attachment,
    aws_iam_role_policy_attachment.eks_cni_policy_attachment,
    aws_iam_role_policy_attachment.ec2_container_registry_read_only,
  ]

  tags = var.tags
}
