# ---------------------------------------------------------------------------
# Rede compartilhada
#
# Topologia: 1 VPC, 2 subnets públicas (worker nodes + Load Balancer) e
# 2 subnets privadas (RDS e Lambda), uma de cada por AZ.
#
# Esta VPC é a "rede da plataforma": os repositórios gearup-infra-db e
# gearup-lambda-auth a encontram pelas tags `Name` e `Camada` (data sources),
# sem depender deste state. Não renomeie as tags sem ajustar os dois repos.
#
# DECISÃO DE CUSTO: não existe NAT Gateway. Ele custaria US$ 0,045/h +
# US$ 0,045/GB e continuaria cobrando fora da sessão do lab. Os nós ficam em
# subnets públicas (com IP público para baixar imagens), protegidos pelo
# security group do cluster, que não abre portas para a internet. RDS e
# Lambda ficam nas privadas, sem rota default: não precisam de internet.
# ---------------------------------------------------------------------------

resource "aws_vpc" "principal" {
  cidr_block           = var.cidr_vpc
  enable_dns_support   = true
  enable_dns_hostnames = true # exigido pelo EKS e pelo RDS

  tags = {
    Name = "${local.prefixo}-vpc"
  }
}

resource "aws_internet_gateway" "principal" {
  vpc_id = aws_vpc.principal.id

  tags = {
    Name = "${local.prefixo}-igw"
  }
}

# A tag kubernetes.io/role/elb=1 permite ao EKS escolher estas subnets para
# o Load Balancer criado pelo Service do tipo LoadBalancer.
resource "aws_subnet" "publica" {
  count = var.quantidade_azs

  vpc_id                  = aws_vpc.principal.id
  availability_zone       = local.azs[count.index]
  cidr_block              = cidrsubnet(var.cidr_vpc, 4, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${local.prefixo}-publica-${local.azs[count.index]}"
    Camada                                      = "publica"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.nome_cluster}" = "shared"
  }
}

resource "aws_subnet" "privada" {
  count = var.quantidade_azs

  vpc_id            = aws_vpc.principal.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr_vpc, 4, count.index + 8)

  tags = {
    Name                                        = "${local.prefixo}-privada-${local.azs[count.index]}"
    Camada                                      = "privada"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.nome_cluster}" = "shared"
  }
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.principal.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.principal.id
  }

  tags = {
    Name = "${local.prefixo}-rt-publica"
  }
}

resource "aws_route_table_association" "publica" {
  count = var.quantidade_azs

  subnet_id      = aws_subnet.publica[count.index].id
  route_table_id = aws_route_table.publica.id
}

# Privada: apenas a rota local da VPC (implícita). Nenhuma rota 0.0.0.0/0.
resource "aws_route_table" "privada" {
  vpc_id = aws_vpc.principal.id

  tags = {
    Name = "${local.prefixo}-rt-privada"
  }
}

resource "aws_route_table_association" "privada" {
  count = var.quantidade_azs

  subnet_id      = aws_subnet.privada[count.index].id
  route_table_id = aws_route_table.privada.id
}
