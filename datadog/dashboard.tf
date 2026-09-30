# ---------------------------------------------------------------------------
# Dashboard "GearUp - Operação"
#
# Grupos exigidos pelo Tech Challenge:
#   1. Volume diário de ordens de serviço
#   2. Tempo médio por status (Diagnóstico, Execução, Finalização)
#   3. Erros e falhas nas integrações
#   4. Latência das APIs
#   5. Consumo de recursos do Kubernetes (CPU e memória)
#   6. Healthchecks e uptime
#   7. Logs de erro correlacionados
#
# O template `$env` alterna entre homolog e production.
# ---------------------------------------------------------------------------

locals {
  f = "service:${var.servico},$env"

  series = {
    os_criadas_dia = {
      titulo = "Ordens de serviço criadas por dia"
      tipo   = "bars"
      query  = "sum:gearup.ordens_servico.criadas{${local.f}}.as_count().rollup(sum, 86400)"
    }
    transicoes = {
      titulo = "Transições de status por status de destino"
      tipo   = "bars"
      query  = "sum:gearup.ordens_servico.transicoes_status{${local.f}} by {gearup.status.atual}.as_count()"
    }
    tempo_status = {
      titulo = "Tempo médio no status (s), por status anterior"
      tipo   = "line"
      query  = "avg:gearup.ordens_servico.tempo_status{${local.f}} by {gearup.status.anterior}"
    }
    erros_api = {
      titulo = "Erros tratados pela API por rota e código"
      tipo   = "bars"
      query  = "sum:gearup.api.erros{${local.f}} by {http.route,gearup.error.code}.as_count()"
    }
    respostas_5xx = {
      titulo = "Respostas 5xx da API (falha de banco ou dependência)"
      tipo   = "bars"
      query  = "count:http.server.request.duration{${local.f},http.response.status_code:5*} by {http.route}.as_count()"
    }
    latencia_p95 = {
      titulo = "Latência p95 por rota (s)"
      tipo   = "line"
      query  = "p95:http.server.request.duration{${local.f}} by {http.route}"
    }
    latencia_p50 = {
      titulo = "Latência p50 geral (s)"
      tipo   = "line"
      query  = "p50:http.server.request.duration{${local.f}}"
    }
    requisicoes = {
      titulo = "Requisições por status HTTP"
      tipo   = "bars"
      query  = "count:http.server.request.duration{${local.f}} by {http.response.status_code}.as_count()"
    }
    cpu_pods = {
      titulo = "CPU por pod (nanocores)"
      tipo   = "line"
      query  = "avg:kubernetes.cpu.usage.total{kube_deployment:gearup-api,$env} by {pod_name}"
    }
    memoria_pods = {
      titulo = "Memória por pod (bytes)"
      tipo   = "line"
      query  = "avg:kubernetes.memory.usage{kube_deployment:gearup-api,$env} by {pod_name}"
    }
    replicas = {
      titulo = "Réplicas disponíveis da API (HPA)"
      tipo   = "line"
      query  = "avg:kubernetes_state.deployment.replicas_available{kube_deployment:gearup-api,$env} by {kube_namespace}"
    }
    tempo_resposta_health = {
      titulo = "Tempo de resposta do /health/ready (s)"
      tipo   = "line"
      query  = "avg:network.http.response_time{service:gearup-api,$env} by {instance}"
    }
  }

  widget_serie = {
    for chave, w in local.series : chave => {
      definition = {
        title       = w.titulo
        type        = "timeseries"
        show_legend = true
        requests = [{
          display_type    = w.tipo
          response_format = "timeseries"
          queries         = [{ data_source = "metrics", name = "q", query = w.query }]
          formulas        = [{ formula = "q" }]
        }]
      }
    }
  }

  grupos = [
    { titulo = "1. Volume de ordens de serviço", widgets = ["os_criadas_dia", "transicoes"] },
    { titulo = "2. Tempo médio por status (Diagnóstico, Execução, Finalização)", widgets = ["tempo_status"] },
    { titulo = "3. Erros e falhas nas integrações", widgets = ["erros_api", "respostas_5xx"] },
    { titulo = "4. Latência das APIs", widgets = ["latencia_p95", "latencia_p50", "requisicoes"] },
    { titulo = "5. Kubernetes: CPU, memória e réplicas", widgets = ["cpu_pods", "memoria_pods", "replicas"] },
    { titulo = "6. Healthchecks e uptime", widgets = ["tempo_resposta_health"] },
  ]

  valor_24h = {
    for titulo, query in {
      "OS criadas (24h)"   = "sum:gearup.ordens_servico.criadas{${local.f}}.as_count()"
      "Erros da API (24h)" = "sum:gearup.api.erros{${local.f}}.as_count()"
      "Requisições (24h)"  = "count:http.server.request.duration{${local.f}}.as_count()"
      } : titulo => {
      definition = {
        title     = titulo
        type      = "query_value"
        precision = 0
        requests = [{
          response_format = "scalar"
          queries         = [{ data_source = "metrics", name = "q", query = query, aggregator = "sum" }]
          formulas        = [{ formula = "q" }]
        }]
      }
    }
  }
}

resource "datadog_dashboard_json" "operacao" {
  dashboard = jsonencode({
    title       = "GearUp - Operação"
    description = "Ordens de serviço, latência, erros, recursos do Kubernetes e uptime. Gerenciado por Terraform (gearup-infra-k8s/datadog)."
    layout_type = "ordered"
    reflow_type = "auto"

    template_variables = [{
      name     = "env"
      prefix   = "env"
      defaults = [var.ambiente_alertas]
    }]

    widgets = concat(
      [{
        definition = {
          title       = "Resumo"
          type        = "group"
          layout_type = "ordered"
          widgets = concat(values(local.valor_24h), [
            {
              definition = {
                title    = "Uptime /health/ready"
                type     = "check_status"
                check    = "http.can_connect"
                grouping = "cluster"
                group_by = []
                tags     = ["service:gearup-api", "$env"]
              }
            },
            {
              definition = {
                title               = "Monitores do GearUp"
                type                = "manage_status"
                query               = "tag:(project:gearup)"
                display_format      = "countsAndList"
                summary_type        = "monitors"
                color_preference    = "text"
                hide_zero_counts    = true
                sort                = "status,asc"
                show_last_triggered = true
              }
            }
          ])
        }
      }],
      [for g in local.grupos : {
        definition = {
          title       = g.titulo
          type        = "group"
          layout_type = "ordered"
          widgets     = [for w in g.widgets : local.widget_serie[w]]
        }
      }],
      [{
        definition = {
          title       = "7. Logs de erro (correlacionados por trace_id e X-Correlation-ID)"
          type        = "group"
          layout_type = "ordered"
          widgets = [{
            definition = {
              title               = "Logs de erro da API"
              type                = "log_stream"
              indexes             = ["*"]
              query               = "service:${var.servico} status:error $env"
              columns             = ["host", "service", "@CorrelationId", "trace_id"]
              show_date_column    = true
              show_message_column = true
              message_display     = "expanded-md"
              sort                = { column = "time", order = "desc" }
            }
          }]
        }
      }]
    )
  })
}
