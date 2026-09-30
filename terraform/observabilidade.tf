# ---------------------------------------------------------------------------
# Observabilidade no cluster
#
#   API (.NET, SDK OpenTelemetry) --OTLP--> OpenTelemetry Collector --> Datadog
#   Datadog Agent (DaemonSet) ----- CPU/memória de nós e pods, healthchecks --> Datadog
#
# O Collector é instalado SEMPRE: sem chave do Datadog ele usa o exporter
# `debug` (telemetria visível em `kubectl logs`), o que permite subir o
# ambiente sem conta no fornecedor. Com `datadog_api_key` preenchida, o
# exporter vira `datadog` e o Agent também é instalado.
#
# A API nunca recebe a chave do Datadog: ela só conhece o endpoint OTLP
# otel-collector.observabilidade.svc.cluster.local:4317 (ver outputs.tf).
#
# CUSTO AWS: zero além do que os pods consomem dos nós já provisionados.
# ---------------------------------------------------------------------------

locals {
  # nonsensitive: o booleano "tem chave?" não revela a chave e pode ir em count.
  datadog_habilitado = nonsensitive(var.datadog_api_key != "")

  exporters_collector = local.datadog_habilitado ? ["datadog/exporter"] : ["debug"]

  config_collector = {
    receivers = {
      otlp = {
        protocols = {
          grpc = { endpoint = "$${env:MY_POD_IP}:4317" }
          http = { endpoint = "$${env:MY_POD_IP}:4318" }
        }
      }
      # Remove receivers que o chart habilita por padrão e não usamos.
      jaeger     = null
      zipkin     = null
      prometheus = null
    }

    processors = {
      memory_limiter = {
        check_interval  = "1s"
        limit_mib       = 300
        spike_limit_mib = 80
      }
      batch = {
        send_batch_size     = 100
        send_batch_max_size = 500
        timeout             = "10s"
      }
    }

    connectors = local.datadog_habilitado ? { "datadog/connector" = {} } : {}

    exporters = merge(
      { debug = { verbosity = "basic" } },
      local.datadog_habilitado ? {
        "datadog/exporter" = {
          api = {
            key  = "$${env:DD_API_KEY}"
            site = var.datadog_site
          }
          # Histogramas do OTel viram distribuições: permite p50/p95/p99 da
          # latência e do tempo por status das ordens de serviço.
          metrics = {
            histograms = { mode = "distributions" }
          }
        }
      } : {}
    )

    service = {
      pipelines = {
        traces = {
          receivers  = ["otlp"]
          processors = ["memory_limiter", "k8sattributes", "batch"]
          exporters  = local.datadog_habilitado ? ["datadog/connector", "datadog/exporter"] : ["debug"]
        }
        metrics = {
          receivers  = local.datadog_habilitado ? ["otlp", "datadog/connector"] : ["otlp"]
          processors = ["memory_limiter", "k8sattributes", "batch"]
          exporters  = local.exporters_collector
        }
        logs = {
          receivers  = ["otlp"]
          processors = ["memory_limiter", "k8sattributes", "batch"]
          exporters  = local.exporters_collector
        }
      }
    }
  }
}

resource "kubernetes_namespace_v1" "observabilidade" {
  metadata {
    name = "observabilidade"
  }

  depends_on = [aws_eks_node_group.principal]
}

resource "kubernetes_secret_v1" "datadog" {
  count = local.datadog_habilitado ? 1 : 0

  metadata {
    name      = "datadog-secret"
    namespace = kubernetes_namespace_v1.observabilidade.metadata[0].name
  }

  data = {
    "api-key" = var.datadog_api_key
  }
}

resource "helm_release" "otel_collector" {
  name       = "otel-collector"
  namespace  = kubernetes_namespace_v1.observabilidade.metadata[0].name
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  version    = var.versao_chart_otel_collector

  values = [yamlencode({
    mode             = "deployment"
    replicaCount     = 1
    fullnameOverride = "otel-collector"

    image = {
      repository = "otel/opentelemetry-collector-contrib"
    }

    # Adiciona k8s.pod.name, k8s.namespace.name etc. a traces, métricas e
    # logs (RBAC do Kubernetes, não IAM da AWS).
    presets = {
      kubernetesAttributes = { enabled = true }
    }

    ports = {
      "jaeger-compact" = { enabled = false }
      "jaeger-thrift"  = { enabled = false }
      "jaeger-grpc"    = { enabled = false }
      zipkin           = { enabled = false }
    }

    extraEnvs = local.datadog_habilitado ? [{
      name = "DD_API_KEY"
      valueFrom = {
        secretKeyRef = {
          name = "datadog-secret"
          key  = "api-key"
        }
      }
    }] : []

    resources = {
      requests = { cpu = "50m", memory = "128Mi" }
      limits   = { memory = "384Mi" }
    }

    config = local.config_collector
  })]

  depends_on = [kubernetes_secret_v1.datadog]
}

resource "helm_release" "datadog_agent" {
  count = local.datadog_habilitado ? 1 : 0

  name       = "datadog"
  namespace  = kubernetes_namespace_v1.observabilidade.metadata[0].name
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  version    = var.versao_chart_datadog

  values = [yamlencode({
    datadog = {
      apiKeyExistingSecret = "datadog-secret"
      site                 = var.datadog_site
      clusterName          = var.nome_cluster
      tags                 = ["project:gearup", "cluster:${var.nome_cluster}"]

      # No EKS o certificado do kubelet não é assinado pela CA do cluster.
      kubelet = { tlsVerify = false }

      # Logs e traces da API chegam pelo Collector (OTLP) já correlacionados;
      # coletá-los também aqui duplicaria a ingestão (e a conta).
      logs = { enabled = false }
      apm  = { portEnabled = false, socketEnabled = false }

      kubeStateMetricsCore = { enabled = true }
      orchestratorExplorer = { enabled = true }
      processAgent         = { enabled = true, processCollection = false }

      # Healthcheck/uptime: o Agent chama /health/ready de cada ambiente e
      # publica o service check `http.can_connect` + `network.http.response_time`.
      confd = {
        "http_check.yaml" = yamlencode({
          init_config = {}
          instances = [for ambiente, url in var.urls_healthcheck : {
            name                      = "gearup-api-${ambiente}"
            url                       = url
            timeout                   = 5
            http_response_status_code = "200"
            tags                      = ["service:gearup-api", "env:${ambiente}"]
          }]
        })
      }
    }

    clusterAgent = {
      enabled  = true
      replicas = 1
      resources = {
        requests = { cpu = "50m", memory = "128Mi" }
        limits   = { memory = "256Mi" }
      }
    }

    agents = {
      containers = {
        agent = {
          resources = {
            requests = { cpu = "100m", memory = "192Mi" }
            limits   = { memory = "384Mi" }
          }
        }
      }
    }
  })]

  depends_on = [kubernetes_secret_v1.datadog]
}
