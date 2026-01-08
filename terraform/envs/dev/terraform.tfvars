env    = "dev"
region = "eu-central-1"

cluster_name    = "my-eks-dev"
cluster_version = "1.29"

vpc_cidr = "10.20.0.0/16"

public_subnet_cidrs = [
  "10.20.0.0/24",
  "10.20.1.0/24"
]

private_subnet_cidrs = [
  "10.20.10.0/24",
  "10.20.11.0/24"
]

eks_public_access_cidrs = [
  "213.252.143.240/28"
]

