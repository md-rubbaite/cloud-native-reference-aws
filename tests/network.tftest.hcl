# Network module: subnet layout, NAT topology and flow logs. Plans only; no AWS credentials needed.

mock_provider "aws" {}

variables {
  name        = "t"
  region      = "eu-west-1"
  azs         = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  kms_key_arn = "arn:aws:kms:eu-west-1:123456789012:key/00000000-0000-0000-0000-000000000000"
}

run "dev_uses_one_shared_nat_gateway" {
  command = plan
  module {
    source = "./modules/network"
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1 && length(aws_route.private_nat) == 3
    error_message = "Expected one NAT gateway serving all three private route tables."
  }
  assert {
    condition     = output.nat_gateway_count == 1
    error_message = "nat_gateway_count output is wrong."
  }
}

run "prod_uses_one_nat_gateway_per_az" {
  command = plan
  module {
    source = "./modules/network"
  }
  variables {
    single_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 3
    error_message = "Expected a NAT gateway in every AZ."
  }
}

run "nat_can_be_disabled" {
  command = plan
  module {
    source = "./modules/network"
  }
  variables {
    enable_nat = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 0 && length(aws_eip.nat) == 0 && length(aws_route.private_nat) == 0
    error_message = "No NAT resources expected when enable_nat is false."
  }
}

run "subnet_layout_and_hardening" {
  command = plan
  module {
    source = "./modules/network"
  }

  assert {
    condition     = [for s in aws_subnet.public : s.cidr_block] == ["10.20.0.0/24", "10.20.1.0/24", "10.20.2.0/24"]
    error_message = "Public subnets should be /24s at the start of the VPC range."
  }
  assert {
    condition     = [for s in aws_subnet.private : s.cidr_block] == ["10.20.16.0/20", "10.20.32.0/20", "10.20.48.0/20"]
    error_message = "Private subnets should be non-overlapping /20s."
  }
  assert {
    condition     = alltrue([for s in aws_subnet.public : s.map_public_ip_on_launch == false])
    error_message = "Nothing should get a public IP automatically, not even in public subnets."
  }
  assert {
    condition     = aws_flow_log.this.traffic_type == "ALL" && aws_cloudwatch_log_group.flow_logs.retention_in_days == 365
    error_message = "Flow logs must capture all traffic and be kept for a year."
  }
  assert {
    condition     = aws_cloudwatch_log_group.flow_logs.kms_key_id == var.kms_key_arn
    error_message = "Flow logs must be encrypted with the customer-managed key."
  }
  assert {
    condition     = aws_vpc_endpoint.s3.service_name == "com.amazonaws.eu-west-1.s3" && aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway"
    error_message = "S3 should use a free gateway endpoint instead of NAT."
  }
}

run "rejects_a_single_az" {
  command = plan
  module {
    source = "./modules/network"
  }
  variables {
    azs = ["eu-west-1a"]
  }
  expect_failures = [var.azs]
}

run "rejects_a_vpc_smaller_than_a_slash_16" {
  command = plan
  module {
    source = "./modules/network"
  }
  variables {
    cidr = "10.0.0.0/24"
  }
  expect_failures = [var.cidr]
}
