module "vpc" {
  source = "./modules/vpc"

  vpc_name           = var.vpc_name
  cidr_block         = var.vpc_cidr
  subnet_cidrs       = [for subnet in var.subnets : subnet.cidr_block]
  availability_zones = [for subnet in var.subnets : subnet.availability_zone]
  cluster_name       = var.cluster_name
}

module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  subnet_ids      = module.vpc.subnet_ids
  node_group_name = var.node_group_name
  instance_types  = var.instance_types
  capacity_type   = var.capacity_type
  desired_size    = var.desired_size
  min_size        = var.min_size
  max_size        = var.max_size
  disk_size       = var.disk_size
}

provider "kubernetes" {
  alias                  = "eks"
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", "us-east-1"]
  }
}

provider "helm" {
  alias = "eks"

  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", "us-east-1"]
    }
  }
}

module "argocd" {
  source = "./modules/argocd"

  providers = {
    kubernetes = kubernetes.eks
    helm       = helm.eks
  }

  depends_on = [module.eks]
}