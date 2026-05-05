data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = var.tags
}

# --- Secondary CIDR for Karpenter (large subnets for prefix delegation) ---

resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  vpc_id     = module.vpc.vpc_id
  cidr_block = "100.64.0.0/16"
}

resource "aws_subnet" "karpenter" {
  count = 2

  vpc_id            = module.vpc.vpc_id
  cidr_block        = cidrsubnet("100.64.0.0/16", 2, count.index) # /18 subnets
  availability_zone = module.vpc.azs[count.index]

  tags = merge(var.tags, {
    Name                     = "${var.cluster_name}-karpenter-${module.vpc.azs[count.index]}"
    "karpenter.sh/discovery" = var.cluster_name
  })

  depends_on = [aws_vpc_ipv4_cidr_block_association.secondary]
}

resource "aws_route_table" "karpenter" {
  count = 2

  vpc_id = module.vpc.vpc_id

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-karpenter-${module.vpc.azs[count.index]}"
  })
}

resource "aws_route" "karpenter_nat" {
  count = 2

  route_table_id         = aws_route_table.karpenter[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = module.vpc.natgw_ids[count.index]
}

resource "aws_route_table_association" "karpenter" {
  count = 2

  subnet_id      = aws_subnet.karpenter[count.index].id
  route_table_id = aws_route_table.karpenter[count.index].id
}
