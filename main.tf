# Composition: network -> database + service -> deploy role -> budget, with one customer-managed key.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  name       = "${var.project}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  is_prod    = var.environment == "prod"
}

# ---------------------------------------------------------------- encryption key
resource "aws_kms_key" "main" {
  description             = "${local.name}: logs, database, secrets and images"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:${local.partition}:iam::${local.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "CloudWatchLogsInThisAccount"
        Effect    = "Allow"
        Principal = { Service = "logs.${var.region}.amazonaws.com" }
        Action    = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
        Resource  = "*"
        Condition = {
          ArnLike = { "kms:EncryptionContext:aws:logs:arn" = "arn:${local.partition}:logs:${var.region}:${local.account_id}:log-group:*" }
        }
      },
    ]
  })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.name}"
  target_key_id = aws_kms_key.main.key_id
}

# ---------------------------------------------------------------- container registry
resource "aws_ecr_repository" "app" {
  name                 = local.name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.main.arn
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the 30 most recent images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 30 }
      action       = { type = "expire" }
    }]
  })
}

# ---------------------------------------------------------------- modules
module "network" {
  source             = "./modules/network"
  name               = local.name
  region             = var.region
  cidr               = var.vpc_cidr
  azs                = var.azs
  single_nat_gateway = var.single_nat_gateway
  kms_key_arn        = aws_kms_key.main.arn
}

module "service" {
  source              = "./modules/service"
  name                = local.name
  region              = var.region
  vpc_id              = module.network.vpc_id
  vpc_cidr            = module.network.vpc_cidr
  public_subnet_ids   = module.network.public_subnet_ids
  private_subnet_ids  = module.network.private_subnet_ids
  container_image     = var.container_image
  certificate_arn     = var.certificate_arn
  desired_count       = var.desired_count
  min_capacity        = local.is_prod ? 2 : 1
  max_capacity        = var.max_capacity
  deletion_protection = local.is_prod
  kms_key_arn         = aws_kms_key.main.arn

  # The application connects to PostgreSQL with IAM authentication as database user "app".
  environment = {
    DB_HOST     = module.database.address
    DB_PORT     = tostring(module.database.port)
    DB_NAME     = module.database.database_name
    DB_USER     = "app"
    DB_IAM_AUTH = "true"
  }
  task_policy_statements = [{
    Sid      = "ConnectAsAppUser"
    Effect   = "Allow"
    Action   = ["rds-db:connect"]
    Resource = ["arn:${local.partition}:rds-db:${var.region}:${local.account_id}:dbuser:${module.database.resource_id}/app"]
  }]
}

module "database" {
  source                     = "./modules/database"
  name                       = local.name
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.private_subnet_ids
  allowed_security_group_ids = [module.service.task_security_group_id]
  instance_class             = var.db_instance_class
  multi_az                   = var.db_multi_az
  deletion_protection        = var.db_deletion_protection
  backup_retention_days      = local.is_prod ? 30 : 7
  kms_key_arn                = aws_kms_key.main.arn
}

module "deploy_role" {
  source               = "./modules/github_oidc"
  github_repository    = var.github_repository
  role_name            = "${local.name}-github-deploy"
  create_oidc_provider = var.create_github_oidc_provider
  ecr_repository_arn   = aws_ecr_repository.app.arn
  ecs_service_arn      = module.service.service_arn
  pass_role_arns       = [module.service.task_role_arn, module.service.execution_role_arn]
}

module "budget" {
  source            = "./modules/budget"
  name              = local.name
  project_tag       = var.project
  monthly_limit_usd = var.monthly_budget_usd
  alert_emails      = var.budget_alert_emails
}
