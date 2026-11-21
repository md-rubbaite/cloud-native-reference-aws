# Deploy role: trust pinned to one repository and explicit refs; least-privilege permissions.

mock_provider "aws" {}

variables {
  github_repository          = "example-org/shop"
  create_oidc_provider       = false
  existing_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  ecr_repository_arn         = "arn:aws:ecr:eu-west-1:123456789012:repository/shop-prod"
  ecs_service_arn            = "arn:aws:ecs:eu-west-1:123456789012:service/shop-prod/shop-prod"
  pass_role_arns             = ["arn:aws:iam::123456789012:role/shop-prod-task", "arn:aws:iam::123456789012:role/shop-prod-execution"]
}

run "trust_is_pinned_to_repository_and_main" {
  command = plan
  module {
    source = "./modules/github_oidc"
  }

  assert {
    condition     = jsondecode(aws_iam_role.deploy.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == ["repo:example-org/shop:ref:refs/heads/main"]
    error_message = "Only the main branch of example-org/shop may assume the role."
  }
  assert {
    condition     = jsondecode(aws_iam_role.deploy.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com"
    error_message = "The token audience must be sts.amazonaws.com."
  }
  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 0
    error_message = "An existing provider was supplied; none should be created."
  }
}

run "release_tags_can_be_allowed_explicitly" {
  command = plan
  module {
    source = "./modules/github_oidc"
  }
  variables {
    allowed_refs = ["refs/heads/main", "refs/tags/v1.0.0"]
  }

  assert {
    condition     = output.subjects == ["repo:example-org/shop:ref:refs/heads/main", "repo:example-org/shop:ref:refs/tags/v1.0.0"]
    error_message = "Each allowed ref must become one exact subject."
  }
}

run "permissions_are_least_privilege" {
  command = plan
  module {
    source = "./modules/github_oidc"
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.deploy.policy).Statement :
      s.Resource != "*" || contains(["EcrLogin", "RegisterTaskDefinitions"], s.Sid)
    ])
    error_message = "Only actions without resource-level support may use Resource = *."
  }
  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.deploy.policy).Statement :
      s.Sid != "PassOnlyTheTaskRoles" || try(s.Condition.StringEquals["iam:PassedToService"], "") == "ecs-tasks.amazonaws.com"
    ])
    error_message = "iam:PassRole must be limited to ECS tasks."
  }
  assert {
    condition     = aws_iam_role.deploy.max_session_duration == 3600
    error_message = "Deploy sessions should last at most an hour."
  }
}

run "creates_the_provider_when_asked" {
  command = plan
  module {
    source = "./modules/github_oidc"
  }
  variables {
    create_oidc_provider       = true
    existing_oidc_provider_arn = null
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 1 && length(aws_iam_openid_connect_provider.github[0].client_id_list) == 1 && contains(aws_iam_openid_connect_provider.github[0].client_id_list, "sts.amazonaws.com")
    error_message = "The GitHub OIDC provider should be created for sts.amazonaws.com."
  }
}

run "rejects_wildcard_repository" {
  command = plan
  module {
    source = "./modules/github_oidc"
  }
  variables {
    github_repository = "example-org/*"
  }
  expect_failures = [var.github_repository]
}

run "rejects_wildcard_refs" {
  command = plan
  module {
    source = "./modules/github_oidc"
  }
  variables {
    allowed_refs = ["refs/heads/*"]
  }
  expect_failures = [var.allowed_refs]
}
