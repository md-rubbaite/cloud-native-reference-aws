# Database module: the database must be private, encrypted, TLS-only and reachable only from the app.

mock_provider "aws" {}

variables {
  name                       = "t"
  vpc_id                     = "vpc-0123456789abcdef0"
  subnet_ids                 = ["subnet-aaaa", "subnet-bbbb"]
  allowed_security_group_ids = ["sg-app"]
  kms_key_arn                = "arn:aws:kms:eu-west-1:123456789012:key/00000000-0000-0000-0000-000000000000"
}

run "secure_defaults" {
  command = plan
  module {
    source = "./modules/database"
  }

  assert {
    condition     = aws_db_instance.this.publicly_accessible == false
    error_message = "The database must not be publicly accessible."
  }
  assert {
    condition     = aws_db_instance.this.storage_encrypted && aws_db_instance.this.kms_key_id == var.kms_key_arn
    error_message = "Storage must be encrypted with the customer-managed key."
  }
  assert {
    condition     = aws_db_instance.this.manage_master_user_password
    error_message = "RDS must manage the master password; no password may appear in configuration or state."
  }
  assert {
    condition     = aws_db_instance.this.iam_database_authentication_enabled
    error_message = "IAM authentication must be on so the application needs no password."
  }
  assert {
    condition     = aws_db_instance.this.deletion_protection && !aws_db_instance.this.skip_final_snapshot
    error_message = "Defaults must protect against deletion and keep a final snapshot."
  }
  assert {
    condition     = aws_db_instance.this.backup_retention_period == 7 && aws_db_instance.this.engine == "postgres"
    error_message = "Unexpected backup retention or engine."
  }
  assert {
    condition     = contains([for p in aws_db_parameter_group.this.parameter : "${p.name}=${p.value}"], "rds.force_ssl=1")
    error_message = "Connections must require TLS (rds.force_ssl = 1)."
  }
  assert {
    condition     = aws_db_parameter_group.this.family == "postgres17"
    error_message = "Parameter group family must follow the engine major version."
  }
}

run "only_the_application_can_connect" {
  command = plan
  module {
    source = "./modules/database"
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.from_app) == 1
    error_message = "Exactly one ingress rule expected."
  }
  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.from_app[0].referenced_security_group_id == "sg-app" &&
      aws_vpc_security_group_ingress_rule.from_app[0].cidr_ipv4 == null &&
      aws_vpc_security_group_ingress_rule.from_app[0].from_port == 5432 &&
      aws_vpc_security_group_ingress_rule.from_app[0].to_port == 5432
    )
    error_message = "Ingress must come only from the application security group on 5432, never from a CIDR."
  }
}

run "production_settings" {
  command = plan
  module {
    source = "./modules/database"
  }
  variables {
    multi_az              = true
    backup_retention_days = 30
    engine_version        = "17.6"
  }

  assert {
    condition     = aws_db_instance.this.multi_az && aws_db_instance.this.backup_retention_period == 30
    error_message = "Production settings were not applied."
  }
  assert {
    condition     = aws_db_parameter_group.this.family == "postgres17"
    error_message = "A minor version must still map to the major-version family."
  }
}

run "rejects_short_backup_retention" {
  command = plan
  module {
    source = "./modules/database"
  }
  variables {
    backup_retention_days = 3
  }
  expect_failures = [var.backup_retention_days]
}

run "rejects_a_single_subnet" {
  command = plan
  module {
    source = "./modules/database"
  }
  variables {
    subnet_ids = ["subnet-aaaa"]
  }
  expect_failures = [var.subnet_ids]
}
