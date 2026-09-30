# ---------------------------------------------------------------------------
# Variáveis de entrada
#
# Os defaults seguem o critério "menor custo que ainda atende o Tech
# Challenge" dentro do AWS Academy Learner Lab (US$ 50, não renovável).
# ---------------------------------------------------------------------------

variable "nome_projeto" {
  description = "Prefixo usado no nome de todos os recursos. Os repos gearup-infra-db e gearup-lambda-auth procuram a VPC por \"<nome_projeto>-vpc\"."
  type        = string
  default     = "gearup"
}

variable "tags_padrao" {
  description = "Tags aplicadas a todos os recursos (via default_tags do provider)."
  type        = map(string)
  default = {
    Projeto     = "GearUp"
    Fase        = "3"
    Repositorio = "gearup-infra-k8s"
    ManagedBy   = "Terraform"
  }
}

# --------------------------------- Rede ------------------------------------

variable "cidr_vpc" {
  description = "Bloco CIDR da VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "quantidade_azs" {
  description = "Quantidade de Availability Zones. O EKS exige no mínimo 2."
  type        = number
  default     = 2

  validation {
    condition     = var.quantidade_azs >= 2 && var.quantidade_azs <= 3
    error_message = "O EKS exige ao menos 2 AZs; acima de 3 só aumenta custo sem ganho no lab."
  }
}

# --------------------------------- EKS -------------------------------------

variable "nome_cluster" {
  description = "Nome do cluster EKS. A pipeline da aplicação usa este nome em `aws eks update-kubeconfig`."
  type        = string
  default     = "gearup-eks"
}

variable "role_cluster" {
  description = "Nome da role IAM do control plane. Vazio = descoberta automática (LabEksClusterRole -> LabRole)."
  type        = string
  default     = ""
}

variable "role_nos" {
  description = "Nome da role IAM dos worker nodes. Vazio = descoberta automática (LabEksNodeRole -> LabRole)."
  type        = string
  default     = ""
}

variable "cidrs_acesso_api_kubernetes" {
  description = "CIDRs autorizados no endpoint público da API do Kubernetes. Os runners do GitHub Actions não têm IP fixo, por isso o padrão é aberto (a autenticação continua via IAM)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tipo_instancia_nos" {
  description = "Tipo de instância dos nós. O Learner Lab só permite nano..large. t3.medium = US$ 0,0416/h por nó."
  type        = string
  default     = "t3.medium"

  validation {
    condition     = can(regex("^[a-z0-9]+[.](nano|micro|small|medium|large)$", var.tipo_instancia_nos))
    error_message = "O Learner Lab permite apenas tamanhos nano, micro, small, medium ou large."
  }
}

variable "nos_desejados" {
  description = "Quantidade inicial de worker nodes."
  type        = number
  default     = 2
}

variable "nos_minimos" {
  description = "Quantidade mínima de worker nodes."
  type        = number
  default     = 1
}

variable "nos_maximos" {
  description = "Quantidade máxima de worker nodes. O lab limita a 9 EC2 simultâneas e 20+ desativam a conta."
  type        = number
  default     = 3

  validation {
    condition     = var.nos_maximos <= 4
    error_message = "Limite de segurança do Learner Lab: no máximo 4 nós."
  }
}

variable "disco_nos_gb" {
  description = "Tamanho do volume EBS de cada nó (máx. 100 GB no lab)."
  type        = number
  default     = 20

  validation {
    condition     = var.disco_nos_gb <= 100
    error_message = "O Learner Lab permite no máximo 100 GB de EBS por volume."
  }
}

variable "nome_repositorio_ecr" {
  description = "Nome do repositório ECR da API."
  type        = string
  default     = "gearup-api"
}

# ---------------------------- Observabilidade -------------------------------

variable "datadog_api_key" {
  description = "API key do Datadog. Vazio = Collector com exporter debug e sem Datadog Agent. Informe via TF_VAR_datadog_api_key (secret DATADOG_API_KEY na pipeline)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "datadog_site" {
  description = "Site do Datadog da sua conta (datadoghq.com, us5.datadoghq.com, datadoghq.eu...)."
  type        = string
  default     = "us5.datadoghq.com"
}

variable "urls_healthcheck" {
  description = "Endpoints de readiness monitorados pelo Datadog Agent (uptime), por ambiente."
  type        = map(string)
  default = {
    homolog    = "http://gearup-api.gearup-homolog.svc.cluster.local/health/ready"
    production = "http://gearup-api.gearup-production.svc.cluster.local/health/ready"
  }
}

variable "versao_chart_otel_collector" {
  description = "Versão do chart open-telemetry/opentelemetry-collector. null = mais recente."
  type        = string
  default     = null
}

variable "versao_chart_datadog" {
  description = "Versão do chart datadog/datadog. null = mais recente."
  type        = string
  default     = null
}
