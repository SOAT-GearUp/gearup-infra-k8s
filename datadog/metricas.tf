# Percentis (p50/p95/p99) em distribuições precisam ser habilitados métrica a
# métrica. São as duas usadas no dashboard e nos alertas.
resource "datadog_metric_tag_configuration" "latencia_http" {
  metric_name         = "http.server.request.duration"
  metric_type         = "distribution"
  tags                = ["env", "service", "http.route", "http.response.status_code", "http.request.method"]
  include_percentiles = true
}

resource "datadog_metric_tag_configuration" "tempo_status_os" {
  metric_name         = "gearup.ordens_servico.tempo_status"
  metric_type         = "distribution"
  tags                = ["env", "service", "gearup.status.anterior", "gearup.status.atual"]
  include_percentiles = true
}
