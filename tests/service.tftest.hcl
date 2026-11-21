# Service module: private tasks, TLS at the edge, safe deployments.

mock_provider "aws" {}

variables {
  name               = "t"
  region             = "eu-west-1"
  vpc_id             = "vpc-0123456789abcdef0"
  vpc_cidr           = "10.20.0.0/16"
  public_subnet_ids  = ["subnet-pub-a", "subnet-pub-b"]
  private_subnet_ids = ["subnet-prv-a", "subnet-prv-b"]
  container_image    = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/shop:2026-11-22.1"
  certificate_arn    = "arn:aws:acm:eu-west-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  kms_key_arn        = "arn:aws:kms:eu-west-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  environment        = { LOG_LEVEL = "info" }
}

run "tasks_are_private" {
  command = plan
  module {
    source = "./modules/service"
  }

  assert {
    condition     = aws_ecs_service.this.network_configuration[0].assign_public_ip == false
    error_message = "Tasks must not get public IPs."
  }
  assert {
    condition     = toset(aws_ecs_service.this.network_configuration[0].subnets) == toset(var.private_subnet_ids)
    error_message = "Tasks must run in the private subnets."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.tasks_from_alb.cidr_ipv4 == null && aws_vpc_security_group_ingress_rule.tasks_from_alb.from_port == 8080
    error_message = "Tasks accept traffic only from the load balancer's security group, on the container port."
  }
}

run "tls_at_the_edge" {
  command = plan
  module {
    source = "./modules/service"
  }

  assert {
    condition     = aws_lb_listener.https.protocol == "HTTPS" && startswith(aws_lb_listener.https.ssl_policy, "ELBSecurityPolicy-TLS13")
    error_message = "HTTPS listener must use a TLS 1.3 policy."
  }
  assert {
    condition = (
      aws_lb_listener.http_redirect.default_action[0].type == "redirect" &&
      aws_lb_listener.http_redirect.default_action[0].redirect[0].protocol == "HTTPS" &&
      aws_lb_listener.http_redirect.default_action[0].redirect[0].status_code == "HTTP_301"
    )
    error_message = "Port 80 must only redirect to HTTPS."
  }
  assert {
    condition     = aws_lb.this.drop_invalid_header_fields
    error_message = "The load balancer must drop invalid headers (request smuggling defence)."
  }
}

run "safe_deployments_and_hardened_container" {
  command = plan
  module {
    source = "./modules/service"
  }

  assert {
    condition     = aws_ecs_service.this.deployment_circuit_breaker[0].enable && aws_ecs_service.this.deployment_circuit_breaker[0].rollback
    error_message = "Failed deployments must roll back automatically."
  }
  assert {
    condition     = aws_ecs_service.this.enable_execute_command == false
    error_message = "ECS Exec must be off by default."
  }
  assert {
    condition = (
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].readonlyRootFilesystem == true &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].privileged == false
    )
    error_message = "Containers must run read-only and unprivileged."
  }
  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].environment == [{ name = "LOG_LEVEL", value = "info" }]
    error_message = "Environment variables were not passed through."
  }
  assert {
    condition     = aws_cloudwatch_log_group.this.retention_in_days == 365 && aws_cloudwatch_log_group.this.kms_key_id == var.kms_key_arn
    error_message = "Application logs must be encrypted and retained."
  }
  assert {
    condition     = length(aws_iam_role_policy.task) == 0
    error_message = "No task policy should exist when no statements are given."
  }
}

run "task_policy_is_created_from_statements" {
  command = plan
  module {
    source = "./modules/service"
  }
  variables {
    task_policy_statements = [{
      Sid      = "ReadOneBucket"
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = ["arn:aws:s3:::shop-assets/*"]
    }]
  }

  assert {
    condition     = length(aws_iam_role_policy.task) == 1
    error_message = "A task policy should be created."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.task[0].policy).Statement[0].Sid == "ReadOneBucket"
    error_message = "The statement was not rendered into the policy."
  }
}

run "rejects_latest_tag" {
  command = plan
  module {
    source = "./modules/service"
  }
  variables {
    container_image = "nginx:latest"
  }
  expect_failures = [var.container_image]
}
