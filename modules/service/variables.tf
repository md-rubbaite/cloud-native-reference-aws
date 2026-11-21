variable "name" {
  type = string

  validation {
    condition     = length(var.name) <= 32
    error_message = "name must be at most 32 characters (load balancer and target group limit)."
  }
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  description = "Tasks may reach PostgreSQL on 5432 inside this range."
  type        = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "container_image" {
  description = "Image reference. Use an immutable digest (repo@sha256:...) or a unique tag; ':latest' is rejected."
  type        = string

  validation {
    condition     = !endswith(var.container_image, ":latest") && length(var.container_image) > 0
    error_message = "Do not deploy ':latest'; use a digest or a unique tag so deployments are reproducible."
  }
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "health_check_path" {
  type    = string
  default = "/healthz"
}

variable "cpu" {
  description = "Fargate CPU units."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate memory in MiB."
  type        = number
  default     = 512
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "min_capacity" {
  type    = number
  default = 2
}

variable "max_capacity" {
  type    = number
  default = 6

  validation {
    condition     = var.max_capacity >= 1
    error_message = "max_capacity must be at least 1."
  }
}

variable "cpu_target_percent" {
  type    = number
  default = 60
}

variable "environment" {
  description = "Non-secret environment variables for the container."
  type        = map(string)
  default     = {}
}

variable "task_policy_statements" {
  description = "IAM statements for the application itself (task role). Empty for none."
  type = list(object({
    Sid      = string
    Effect   = string
    Action   = list(string)
    Resource = list(string)
  }))
  default = []
}

variable "certificate_arn" {
  description = "ACM certificate for the HTTPS listener."
  type        = string
}

variable "ssl_policy" {
  description = "TLS 1.3 with TLS 1.2 fallback."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "access_logs_bucket" {
  description = "Optional S3 bucket for load balancer access logs."
  type        = string
  default     = null
}

variable "log_retention_days" {
  type    = number
  default = 365
}

variable "kms_key_arn" {
  type = string
}
