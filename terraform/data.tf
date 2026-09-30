# ---------------------------------------------------------------------------
# Data sources
#
# Nenhuma role/policy IAM é criada aqui: o Learner Lab proíbe criar usuários,
# grupos e roles. As roles pré-existentes do lab são apenas referenciadas.
# É também o motivo de não usarmos o módulo terraform-aws-modules/eks (ele
# cria IAM por padrão).
# ---------------------------------------------------------------------------

data "aws_availability_zones" "disponiveis" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Cada conta de Learner Lab nomeia as roles do EKS com um sufixo próprio
# (ex.: c2205...-LabEksClusterRole-rPckPp64hltK), então a busca é por regex.
# Precedência: nome explícito na variável -> role específica de EKS -> LabRole.
data "aws_iam_roles" "eks_cluster" {
  name_regex = ".*LabEksClusterRole.*"
}

data "aws_iam_roles" "eks_nos" {
  name_regex = ".*LabEksNodeRole.*"
}

data "aws_iam_role" "lab" {
  name = "LabRole"
}

data "aws_iam_role" "cluster_explicita" {
  count = var.role_cluster == "" ? 0 : 1
  name  = var.role_cluster
}

data "aws_iam_role" "nos_explicita" {
  count = var.role_nos == "" ? 0 : 1
  name  = var.role_nos
}

locals {
  azs     = slice(data.aws_availability_zones.disponiveis.names, 0, var.quantidade_azs)
  prefixo = var.nome_projeto

  arn_role_cluster = coalesce(
    try(data.aws_iam_role.cluster_explicita[0].arn, null),
    try(tolist(data.aws_iam_roles.eks_cluster.arns)[0], null),
    data.aws_iam_role.lab.arn,
  )

  arn_role_nos = coalesce(
    try(data.aws_iam_role.nos_explicita[0].arn, null),
    try(tolist(data.aws_iam_roles.eks_nos.arns)[0], null),
    data.aws_iam_role.lab.arn,
  )
}
