output "nome_cluster" {
  description = "Nome do cluster EKS."
  value       = aws_eks_cluster.principal.name
}

output "comando_kubeconfig" {
  description = "Configura o kubectl local para o cluster."
  value       = "aws eks update-kubeconfig --region us-east-1 --name ${aws_eks_cluster.principal.name}"
}

output "vpc_id" {
  description = "VPC compartilhada (consumida por gearup-infra-db e gearup-lambda-auth via tag Name)."
  value       = aws_vpc.principal.id
}

output "subnets_publicas" {
  description = "Subnets dos nós e do Load Balancer."
  value       = aws_subnet.publica[*].id
}

output "subnets_privadas" {
  description = "Subnets do RDS e da Lambda."
  value       = aws_subnet.privada[*].id
}

output "security_group_cluster" {
  description = "Security group gerenciado do cluster (anexado aos nós e pods)."
  value       = aws_eks_cluster.principal.vpc_config[0].cluster_security_group_id
}

output "repositorio_ecr" {
  description = "URL do repositório ECR da API."
  value       = aws_ecr_repository.api.repository_url
}

output "endpoint_otlp" {
  description = "Endpoint OTLP/gRPC que a API usa em OTEL_EXPORTER_OTLP_ENDPOINT."
  value       = "http://otel-collector.observabilidade.svc.cluster.local:4317"
}

output "datadog_habilitado" {
  description = "Indica se o Datadog Agent foi instalado."
  value       = local.datadog_habilitado
}
