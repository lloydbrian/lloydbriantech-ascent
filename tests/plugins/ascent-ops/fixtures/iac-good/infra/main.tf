terraform {
  required_version = "~> 1.9"
  backend "s3" {
    bucket       = "example-tfstate"
    key          = "app/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

# Values per environment come from <env>.tfvars.
variable "environment" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "image_tag" {
  type    = string
  default = "1.4.2"
}

resource "aws_secretsmanager_secret" "db" {
  name = "app/${var.environment}/db"
}

resource "aws_secretsmanager_secret_rotation" "db" {
  secret_id           = aws_secretsmanager_secret.db.id
  rotation_lambda_arn = "arn:aws:lambda:us-east-1:000000000000:function:rotate"
  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_ssm_parameter" "api_token" {
  name  = "/app/${var.environment}/api-token"
  type  = "SecureString"
  value = var.db_password
}

resource "aws_ecs_task_definition" "app" {
  family = "app"
  container_definitions = jsonencode([
    {
      name  = "app"
      image = "registry.example/app:${var.image_tag}"
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "APP_ENV", value = var.environment }
      ]
      secrets = [
        { name = "DB_PASSWORD", valueFrom = aws_secretsmanager_secret.db.arn }
      ]
    }
  ])
}

data "aws_iam_policy_document" "read_secret" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.db.arn]
  }
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}
