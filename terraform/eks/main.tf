data "aws_availability_zones" "available" {}

locals {
  name = "${var.project_name}-${var.environment}-eks"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# IAM Role for EBS CSI Driver
resource "aws_iam_role" "ebs_csi_role" {
  name = "${var.project_name}-${var.environment}-ebs-csi-role"

  assume_role_policy = file("${path.module}/ebs-csi-trust-policy.json")

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_role.name
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = "10.0.0.0/16"

  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  private_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  public_subnets = [
    "10.0.101.0/24",
    "10.0.102.0/24"
  ]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Enable cluster addons for EBS CSI driver
  cluster_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = aws_iam_role.ebs_csi_role.arn
    }
    vpc-cni = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    sock_shop = {
      name = "sock-shop-node-group"

      iam_role_name            = "sockshop-${var.environment}-ng-role"
      iam_role_use_name_prefix = false

      capacity_type  = "ON_DEMAND"
      instance_types = ["c6i.large"]  # 2 vCPU, 4GB RAM - optimized for microservices

      min_size     = 2
      max_size     = 5
      desired_size = 3

      disk_size      = 50
      disk_type      = "gp3"
      disk_iops      = 3000
      disk_throughput = 125
      disk_encrypted = true

      labels = {
        Environment = var.environment
        WorkloadType = "general"
      }

      tags = merge(
        local.tags,
        {
          NodeGroup = "sock-shop"
        }
      )
    }
  }

  tags = local.tags
}