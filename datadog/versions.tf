# ---------------------------------------------------------------------------
# Dashboards e monitores do Datadog como código
#
# State separado do cluster (chave infra-k8s/datadog.tfstate): recursos do
# Datadog não custam nada na AWS e podem ser recriados sem tocar no EKS.
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 3.60"
    }
  }

  backend "s3" {
    key          = "infra-k8s/datadog.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

# Credenciais via DD_API_KEY / DD_APP_KEY (secrets DATADOG_API_KEY e
# DATADOG_APP_KEY na pipeline).
provider "datadog" {
  api_url = "https://api.${var.datadog_site}/"
}
