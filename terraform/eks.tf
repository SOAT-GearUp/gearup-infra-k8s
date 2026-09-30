# ---------------------------------------------------------------------------
# Cluster EKS + Node Group
#
# Recursos nativos (`aws_eks_cluster` / `aws_eks_node_group`) em vez do módulo
# da comunidade, porque o módulo cria roles e policies IAM — proibido no lab.
#
# CUSTO: o control plane cobra US$ 0,10/h 24/7, INCLUSIVE com a sessão do lab
# encerrada. Cada nó t3.medium soma US$ 0,0416/h. Rode o workflow de destroy
# (ou `terraform destroy`) ao fim de cada sessão.
# ---------------------------------------------------------------------------

resource "aws_eks_cluster" "principal" {
  name     = var.nome_cluster
  role_arn = local.arn_role_cluster

  # `version` deliberadamente omitido: a AWS escolhe a mais recente. Uma
  # versão antiga cairia em "extended support" (US$ 0,60/h em vez de 0,10/h).

  vpc_config {
    subnet_ids              = concat(aws_subnet.publica[*].id, aws_subnet.privada[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.cidrs_acesso_api_kubernetes
  }

  access_config {
    # Dá admin no cluster a quem rodou o apply (a role `voclabs` do lab, que é
    # a mesma usada pela pipeline e pela máquina do desenvolvedor).
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Logs do control plane desligados: cobrariam ingestão no CloudWatch.

  tags = {
    Name = var.nome_cluster
  }
}

resource "aws_eks_node_group" "principal" {
  cluster_name    = aws_eks_cluster.principal.name
  node_group_name = "${local.prefixo}-ng-principal"
  node_role_arn   = local.arn_role_nos

  # Subnets públicas para dispensar o NAT Gateway. O managed node group cria
  # o instance profile a partir da role — nenhum recurso IAM é declarado.
  subnet_ids = aws_subnet.publica[*].id

  instance_types = [var.tipo_instancia_nos]
  ami_type       = "AL2023_x86_64_STANDARD"
  disk_size      = var.disco_nos_gb
  capacity_type  = "ON_DEMAND" # Spot é bloqueado no Learner Lab

  scaling_config {
    desired_size = var.nos_desejados
    min_size     = var.nos_minimos
    max_size     = var.nos_maximos # teto baixo: 20+ instâncias desativam a conta
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    workload = "gearup"
  }

  tags = {
    Name = "${local.prefixo}-node"
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# Addons gerenciados. O metrics-server é pré-requisito do HPA: sem ele o HPA
# mostra `<unknown>/70%` e nunca escala.
resource "aws_eks_addon" "principais" {
  for_each = toset(["vpc-cni", "kube-proxy", "coredns", "metrics-server"])

  cluster_name                = aws_eks_cluster.principal.name
  addon_name                  = each.value
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.principal]
}
