# ---------------------------------------------------------------------------
# Registro de imagens da API
#
# A pipeline do repositório gearup-api publica aqui uma imagem por commit (tag =
# SHA). Tags imutáveis garantem que um rollback volte exatamente ao binário
# testado. `force_delete` permite o destroy do lab mesmo com imagens.
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "api" {
  name                 = var.nome_repositorio_ecr
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Mantém as últimas 15 imagens: o armazenamento do ECR cobra por GB/mês.
resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Mantem as ultimas 15 imagens"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 15
      }
      action = { type = "expire" }
    }]
  })
}
