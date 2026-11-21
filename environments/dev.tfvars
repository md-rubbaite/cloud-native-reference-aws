# Development: two AZs, one shared NAT gateway, single-AZ database without deletion protection.
project     = "shop"
environment = "dev"
owner       = "platform-team"
region      = "eu-west-1"
azs         = ["eu-west-1a", "eu-west-1b"]

single_nat_gateway = true
container_image    = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/shop-dev:2026-11-22.1"
certificate_arn    = "arn:aws:acm:eu-west-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
desired_count      = 1
max_capacity       = 3

db_instance_class      = "db.t4g.micro"
db_multi_az            = false
db_deletion_protection = false

github_repository   = "example-org/shop"
monthly_budget_usd  = 150
budget_alert_emails = ["platform-team@example.com"]
