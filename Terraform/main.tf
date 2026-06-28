# 1. Configuração do Provedor AWS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "default" # Isso força o Terraform a olhar para o seu arquivo ~/.aws/credentials
}

# 2. Repositório ECR
resource "aws_ecr_repository" "poc_app_db_secrets_repo" {
  name                 = "poc-app-db-secrets-repo"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# 3. Segredo no Secrets Manager
resource "aws_secretsmanager_secret" "poc_db_secret" {
  name                    = "POC-DBSecret"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "poc_db_secret_version" {
  secret_id     = aws_secretsmanager_secret.poc_db_secret.id
  secret_string = "Hello World! Conteúdo do Secret."
}

# 4. Role da Aplicação (Task Role - "Crachá do container")
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

resource "aws_iam_role_policy" "read_secret_policy" {
  name = "poc-read-secret-policy"
  role = aws_iam_role.app_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["secretsmanager:GetSecretValue"]
      Effect   = "Allow"
      Resource = [aws_secretsmanager_secret.poc_db_secret.arn]
    }]
  })
}

# 5. OIDC: Confiança entre GitHub e AWS
resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] 
}

# 6. Role do GitHub Actions (A "esteira")
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
          "token.actions.githubusercontent.com:sub": "repo:EHUVF/POC-SecretManager:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_power_user" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# 7. Outputs para consulta
output "ecr_repository_url" {
  value = aws_ecr_repository.poc_app_db_secrets_repo.repository_url
}

output "github_role_arn" {
  description = "ARN que você deve colar no seu deploy.yml"
  value       = aws_iam_role.github_actions_role.arn
}