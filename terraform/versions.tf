# ---------------------------------------------------------------------------
# Versões e backend do state
#
# O state fica num bucket S3 da própria conta (gearup-tfstate-<account_id>),
# criado de forma idempotente por scripts/tf-init.sh. O backend é declarado
# vazio ("partial configuration") porque o nome do bucket depende da conta:
# cada Learner Lab tem um account id diferente.
#
# Por que S3 e não state local: a pipeline do GitHub Actions precisa
# enxergar o mesmo state que a máquina do desenvolvedor. `use_lockfile`
# usa o lock nativo do S3 e dispensa a tabela DynamoDB (custo zero extra).
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }

  backend "s3" {
    key          = "infra-k8s/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
