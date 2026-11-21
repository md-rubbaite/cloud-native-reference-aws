# Production: three AZs, one NAT gateway per AZ, Multi-AZ database with deletion protection.
project     = "shop"
environment = "prod"
owner       = "platform-team"
region      = "eu-west-1"
azs         = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

single_nat_gateway = false
container_image    = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/shop-prod@sha256:4f1c2d3e4b5a69788796a5b4c3d2e1f00112233445566778899aabbccddeeff0"
certificate_arn    = "arn:aws:acm:eu-west-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
desired_count      = 3
max_capacity       = 12

db_instance_class      = "db.m7g.large"
db_multi_az            = true
db_deletion_protection = true

github_repository   = "example-org/shop"
monthly_budget_usd  = 1500
budget_alert_emails = ["platform-team@example.com", "finance@example.com"]
