variable "datadog_site" {
  description = "Site do Datadog (datadoghq.com, us5.datadoghq.com, datadoghq.eu...)."
  type        = string
  default     = "us5.datadoghq.com"
}

variable "servico" {
  description = "Nome do serviço (resource attribute service.name da API)."
  type        = string
  default     = "gearup-api"
}

variable "ambiente_alertas" {
  description = "Ambiente monitorado pelos alertas (tag env)."
  type        = string
  default     = "production"
}

variable "namespace_kubernetes" {
  description = "Namespace da API no ambiente monitorado pelos alertas."
  type        = string
  default     = "gearup-production"
}

variable "destino_notificacao" {
  description = "Destino das notificações, no formato do Datadog (ex.: \"@time@exemplo.com\"). Vazio = sem notificação, alerta só no painel."
  type        = string
  default     = ""
}
