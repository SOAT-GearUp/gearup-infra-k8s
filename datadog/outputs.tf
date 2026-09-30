output "url_dashboard" {
  description = "URL do dashboard de operação."
  value       = "https://app.${var.datadog_site}${datadog_dashboard_json.operacao.url}"
}

output "monitores" {
  description = "IDs dos monitores criados."
  value       = merge({ for k, m in datadog_monitor.gearup : k => m.id }, { healthcheck = datadog_monitor.healthcheck.id })
}
