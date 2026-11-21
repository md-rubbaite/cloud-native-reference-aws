variable "name" {
  description = "Identifier prefix for the database resources."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnets in at least two AZs."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "RDS needs subnets in at least two availability zones."
  }
}

variable "allowed_security_group_ids" {
  description = "Security groups (the application tasks) allowed to connect on 5432."
  type        = list(string)
}

variable "engine_version" {
  description = "PostgreSQL major or major.minor version."
  type        = string
  default     = "17"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "database_name" {
  type    = string
  default = "app"
}

variable "allocated_storage" {
  description = "Initial storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling in GiB."
  type        = number
  default     = 100

  validation {
    condition     = var.max_allocated_storage >= 20
    error_message = "max_allocated_storage must be at least 20 GiB."
  }
}

variable "multi_az" {
  description = "Synchronous standby in a second AZ."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "backup_retention_days" {
  type    = number
  default = 7

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 35
    error_message = "Keep automated backups between 7 and 35 days."
  }
}

variable "slow_query_ms" {
  description = "Log statements slower than this many milliseconds."
  type        = number
  default     = 500
}

variable "kms_key_arn" {
  description = "Customer-managed key for storage, Performance Insights and the master secret."
  type        = string
}
