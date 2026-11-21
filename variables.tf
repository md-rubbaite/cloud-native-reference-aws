variable "project" {
  description = "Short project name; prefixes resources and drives the cost-allocation tag."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.project))
    error_message = "project must be 2-16 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "owner" {
  description = "Team or person accountable for the resources (tag)."
  type        = string
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "azs" {
  type = list(string)
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

variable "container_image" {
  description = "Initial image; CI deploys later versions by registering new task definitions."
  type        = string
}

variable "certificate_arn" {
  type = string
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "max_capacity" {
  type    = number
  default = 6
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_deletion_protection" {
  type    = bool
  default = true

  validation {
    condition     = var.environment != "prod" || var.db_deletion_protection
    error_message = "Production databases must have deletion protection."
  }
}

variable "github_repository" {
  description = "owner/repo whose main-branch workflows may deploy."
  type        = string
}

variable "create_github_oidc_provider" {
  type    = bool
  default = true
}

variable "monthly_budget_usd" {
  type = number
}

variable "budget_alert_emails" {
  type = list(string)
}
