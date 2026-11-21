mock_provider "aws" {}

variables {
  name              = "shop-dev"
  project_tag       = "shop"
  monthly_limit_usd = 150
  alert_emails      = ["platform-team@example.com"]
}

run "budget_filters_on_the_project_tag" {
  command = plan
  module {
    source = "./modules/budget"
  }

  assert {
    condition     = aws_budgets_budget.this.limit_amount == "150.00" && aws_budgets_budget.this.time_unit == "MONTHLY"
    error_message = "Monthly limit not set as expected."
  }
  assert {
    condition     = [for v in one([for f in aws_budgets_budget.this.cost_filter : f.values]) : v] == ["user:Project$shop"]
    error_message = "The budget must track spend for the Project tag only."
  }
  assert {
    condition     = toset([for n in aws_budgets_budget.this.notification : "${n.notification_type}:${n.threshold}"]) == toset(["ACTUAL:80", "FORECASTED:100"])
    error_message = "Expected alerts at 80% actual and 100% forecast."
  }
}

run "rejects_invalid_email" {
  command = plan
  module {
    source = "./modules/budget"
  }
  variables {
    alert_emails = ["not-an-email"]
  }
  expect_failures = [var.alert_emails]
}
