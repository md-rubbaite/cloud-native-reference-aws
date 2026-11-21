# Whole stack, planned with the dev and prod settings. Proves the modules wire together.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
}

variables {
  project             = "shop"
  owner               = "platform-team"
  region              = "eu-west-1"
  github_repository   = "example-org/shop"
  certificate_arn     = "arn:aws:acm:eu-west-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  budget_alert_emails = ["platform-team@example.com"]
}

run "dev_stack" {
  command = plan
  variables {
    environment            = "dev"
    azs                    = ["eu-west-1a", "eu-west-1b"]
    single_nat_gateway     = true
    container_image        = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/shop-dev:2026-11-22.1"
    desired_count          = 1
    db_deletion_protection = false
    monthly_budget_usd     = 150
  }

  assert {
    condition     = output.nat_gateway_count == 1
    error_message = "Dev should use a single NAT gateway."
  }
  assert {
    condition     = aws_ecr_repository.app.image_tag_mutability == "IMMUTABLE" && aws_ecr_repository.app.image_scanning_configuration[0].scan_on_push
    error_message = "Images must be immutable and scanned on push."
  }
  assert {
    condition     = aws_kms_key.main.enable_key_rotation
    error_message = "The customer-managed key must rotate."
  }
}

run "prod_stack" {
  command = plan
  variables {
    environment            = "prod"
    azs                    = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
    single_nat_gateway     = false
    container_image        = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/shop-prod@sha256:4f1c2d3e4b5a69788796a5b4c3d2e1f00112233445566778899aabbccddeeff0"
    desired_count          = 3
    max_capacity           = 12
    db_multi_az            = true
    db_deletion_protection = true
    monthly_budget_usd     = 1500
  }

  assert {
    condition     = output.nat_gateway_count == 3
    error_message = "Prod should have one NAT gateway per AZ."
  }
}

run "prod_requires_database_deletion_protection" {
  command = plan
  variables {
    environment            = "prod"
    azs                    = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
    container_image        = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/shop-prod:1.0.0"
    db_deletion_protection = false
    monthly_budget_usd     = 1500
  }
  expect_failures = [var.db_deletion_protection]
}
