provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

# 1. Repositório ECR
resource "aws_ecr_repository" "poc_app_db_secrets_repo" {
  name = "poc-app-db-secrets-repo"
}

# 2. Provedor OIDC para o GitHub
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["d89e3bd43d5d909b47a18977aa9d5ce36cee184c"]
}

# 3. Role para o GitHub Actions
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

# 4. Permissões da Role do GitHub
resource "aws_iam_role_policy" "github_deploy_policy" {
  role = aws_iam_role.github_actions_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecs:UpdateService",
        "ecs:DescribeServices"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

# 5. ECS Cluster
resource "aws_ecs_cluster" "poc_cluster" {
  name = "poc-cluster"
}

# 6. ECS Task Definition
resource "aws_ecs_task_definition" "poc_task" {
  family                   = "poc-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "arn:aws:iam::263611243832:role/ecsTaskExecutionRole" # Role padrão do ECS

  container_definitions = jsonencode([{
    name  = "poc-container"
    image = "${aws_ecr_repository.poc_app_db_secrets_repo.repository_url}:latest"
    portMappings = [{ containerPort = 80 }]
  }])
}

# 7. ECS Service
resource "aws_ecs_service" "poc_service" {
  name            = "poc-service"
  cluster         = aws_ecs_cluster.poc_cluster.id
  task_definition = aws_ecs_task_definition.poc_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["subnet-001b8db286dc31ae8"] # A subnet que validamos
    assign_public_ip = true
  }
}