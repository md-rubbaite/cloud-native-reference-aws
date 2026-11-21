variable "github_repository" {
  description = "owner/repo allowed to assume the deploy role."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "github_repository must look like owner/repo (no wildcards)."
  }
}

variable "allowed_refs" {
  description = "Git refs whose workflows may deploy, e.g. refs/heads/main or refs/tags/v1.2.3."
  type        = list(string)
  default     = ["refs/heads/main"]

  validation {
    condition     = length(var.allowed_refs) > 0 && alltrue([for r in var.allowed_refs : startswith(r, "refs/") && !strcontains(r, "*")])
    error_message = "List explicit refs starting with refs/; wildcards would let any branch deploy."
  }
}

variable "role_name" {
  type    = string
  default = "github-deploy"
}

variable "create_oidc_provider" {
  description = "An account has one provider per issuer; set false and pass existing_oidc_provider_arn if it already exists."
  type        = bool
  default     = true
}

variable "existing_oidc_provider_arn" {
  type    = string
  default = null
}

variable "ecr_repository_arn" {
  type = string
}

variable "ecs_service_arn" {
  type = string
}

variable "pass_role_arns" {
  description = "Task and execution role ARNs the deploy may hand to ECS."
  type        = list(string)
}
