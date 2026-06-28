# Configure o provider da AWS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Cria um repositório no ECR
resource "aws_ecr_repository" "poc_app_db_secrets_repo" {
  name                 = "poc-app-db-secrets-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "poc-app-db-secrets-repo"
  }
}

# Cria um segredo no AWS Secrets Manager
resource "aws_secretsmanager_secret" "poc_db_secret" {
  name                    = "POC-DBSecret"
  recovery_window_in_days = 7

  tags = {
    Name = "POC-DBSecret"
  }
}

# Adiciona uma versão inicial do segredo
resource "aws_secretsmanager_secret_version" "poc_db_secret_version" {
  secret_id     = aws_secretsmanager_secret.poc_db_secret.id
  secret_string = "Hello World! Eu sou o conteúdo do Secret!"
}

# Outputs
output "ecr_repository_url" {
  description = "URL do repositório ECR"
  value       = aws_ecr_repository.poc_app_db_secrets_repo.repository_url
}

output "secret_arn" {
  description = "ARN do segredo no Secrets Manager"
  value       = aws_secretsmanager_secret.poc_db_secret.arn
}

# 1. A Role que o Fargate vai assumir (O "crachá")
resource "aws_iam_role" "app_task_role" {
  name = "poc-app-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# 2. Permissão específica para ler o seu segredo
resource "aws_iam_role_policy" "read_secret_policy" {
  name = "poc-read-secret-policy"
  role = aws_iam_role.app_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["secretsmanager:GetSecretValue"]
      Effect   = "Allow"
      Resource = ["${aws_secretsmanager_secret.poc_db_secret.arn}"]
    }]
  })
}

# 1. OIDC Provider: "AWS, confie no GitHub"
resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # Thumbprint do GitHub Actions (padronizado)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] 
}

# 2. Role que o GitHub vai assumir (O "crachá" para a esteira)
resource "aws_iam_role" "github_actions_role" {
  name = "poc-github-actions-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          # AQUI ESTÁ O AJUSTE DO SEU REPOSITÓRIO:
          "token.actions.githubusercontent.com:sub": "repo:EHUVF/POC-SecretManager:*"
        }
      }
    }]
  })
}

# 3. Permissão para o GitHub fazer push no seu ECR
resource "aws_iam_role_policy_attachment" "ecr_power_user" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}