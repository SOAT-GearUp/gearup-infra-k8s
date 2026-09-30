# ---------------------------------------------------------------------------
# Monitores (alertas)
#
# Todos levam a tag project:gearup e aparecem no widget "Monitores do GearUp"
# do dashboard.
# ---------------------------------------------------------------------------

locals {
  filtro_api = "service:${var.servico},env:${var.ambiente_alertas}"
  notificar  = var.destino_notificacao == "" ? "" : "\n\n${var.destino_notificacao}"
  tags       = ["project:gearup", "service:${var.servico}", "env:${var.ambiente_alertas}", "managed-by:terraform"]

  monitores = {
    falhas_os = {
      nome     = "[GearUp] Falhas no processamento de ordens de serviço"
      tipo     = "query alert"
      query    = "sum(last_5m):sum:gearup.api.erros{${local.filtro_api},http.route:api/ordens-servico*}.as_count() > 5"
      critico  = 5
      alerta   = 1
      mensagem = "Mais de {{threshold}} erros em rotas de ordens de serviço nos últimos 5 minutos (valor: {{value}}). Ver o grupo 3 do dashboard GearUp - Operação e os logs com status:error."
    }
    erro_nao_tratado = {
      nome     = "[GearUp] Erro não tratado na API"
      tipo     = "log alert"
      query    = "logs(\"service:${var.servico} env:${var.ambiente_alertas} status:error\").index(\"*\").rollup(\"count\").last(\"5m\") > 0"
      critico  = 0
      alerta   = null
      mensagem = "A API registrou erros não tratados. Abra o log e siga o trace_id / X-Correlation-ID até a requisição de origem."
    }
    latencia = {
      nome     = "[GearUp] Latência p95 da API acima de 1s"
      tipo     = "query alert"
      query    = "percentile(last_10m):p95:http.server.request.duration{${local.filtro_api}} > 1"
      critico  = 1
      alerta   = 0.5
      mensagem = "p95 da latência HTTP em {{value}}s. Verifique CPU dos pods e réplicas do HPA no dashboard."
    }
    cpu = {
      nome     = "[GearUp] CPU dos pods da API acima de 80% do limite"
      tipo     = "query alert"
      query    = "avg(last_10m):avg:kubernetes.cpu.usage.total{kube_namespace:${var.namespace_kubernetes},kube_deployment:gearup-api} by {pod_name} > 400000000"
      critico  = 400000000
      alerta   = 300000000
      mensagem = "Pod {{pod_name.name}} usando {{value}} nanocores (limite 500m). Se persistir com o HPA no teto, aumente maxReplicas ou os nós."
    }
    memoria = {
      nome     = "[GearUp] Memória dos pods da API acima de 85% do limite"
      tipo     = "query alert"
      query    = "avg(last_10m):avg:kubernetes.memory.usage{kube_namespace:${var.namespace_kubernetes},kube_deployment:gearup-api} by {pod_name} > 456340275"
      critico  = 456340275
      alerta   = 402653184
      mensagem = "Pod {{pod_name.name}} usando {{value}} bytes de memória (limite 512Mi). Risco de OOMKill."
    }
    reinicios = {
      nome     = "[GearUp] Pods da API reiniciando"
      tipo     = "query alert"
      query    = "change(max(last_10m),last_10m):sum:kubernetes.containers.restarts{kube_namespace:${var.namespace_kubernetes},kube_deployment:gearup-api} by {pod_name} > 2"
      critico  = 2
      alerta   = null
      mensagem = "O pod {{pod_name.name}} reiniciou mais de 2 vezes em 10 minutos. Verifique liveness probe e OOMKilled."
    }
    # A Lambda de autenticação é monitorada por alarmes do CloudWatch
    # (gearup-lambda-auth/terraform/monitoramento.tf): sem NAT, ela não
    # alcança a internet para enviar telemetria ao Datadog.
  }
}

resource "datadog_monitor" "gearup" {
  for_each = local.monitores

  name    = each.value.nome
  type    = each.value.tipo
  query   = each.value.query
  message = "${each.value.mensagem}${local.notificar}"
  tags    = local.tags

  monitor_thresholds {
    critical = each.value.critico
    warning  = each.value.alerta
  }

  notify_no_data      = false
  require_full_window = false
  include_tags        = true
}

# Uptime: service check publicado pelo http_check do Datadog Agent
# (configurado em gearup-infra-k8s/terraform/observabilidade.tf).
resource "datadog_monitor" "healthcheck" {
  name    = "[GearUp] Healthcheck /health/ready falhando"
  type    = "service check"
  query   = "\"http.can_connect\".over(\"service:${var.servico}\",\"env:${var.ambiente_alertas}\").by(\"instance\").last(3).count_by_status()"
  message = "O endpoint de readiness de {{instance.name}} falhou 3 verificações seguidas. A API ou o banco podem estar fora.${local.notificar}"
  tags    = local.tags

  monitor_thresholds {
    critical = 2
    warning  = 1
    ok       = 1
  }

  notify_no_data    = true
  no_data_timeframe = 10
}
