# ---------------------------------------------------------------------------
# Providers
#
# Região fixa em us-east-1: o Learner Lab só libera us-east-1 e us-west-2 e o
# key pair `vockey` existe apenas em us-east-1. As credenciais vêm de
# variáveis de ambiente (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY e
# AWS_SESSION_TOKEN) ou de ~/.aws/credentials — nunca de arquivos versionados.
# ---------------------------------------------------------------------------
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = var.tags_padrao
  }
}

# Helm e Kubernetes falam com o cluster criado neste mesmo state. O token é
# obtido via `aws eks get-token` a cada chamada, então não há kubeconfig nem
# credencial estática envolvida.
locals {
  exec_kubernetes = {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.principal.name, "--region", "us-east-1"]
  }
}

provider "kubernetes" {
  host                   = aws_eks_cluster.principal.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.principal.certificate_authority[0].data)

  exec {
    api_version = local.exec_kubernetes.api_version
    command     = local.exec_kubernetes.command
    args        = local.exec_kubernetes.args
  }
}

provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.principal.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.principal.certificate_authority[0].data)
    exec                   = local.exec_kubernetes
  }
}
