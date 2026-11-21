variable "name" {
  description = "Prefix for every resource name."
  type        = string
}

variable "region" {
  description = "AWS region, used for the S3 gateway endpoint service name."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block. A /16 leaves room for /24 public and /20 private subnets."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.cidr)) && try(tonumber(split("/", var.cidr)[1]) <= 16, false)
    error_message = "cidr must be a valid IPv4 block of /16 or larger."
  }
}

variable "azs" {
  description = "Availability zones to spread subnets across (2 or 3)."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2 && length(var.azs) <= 3 && length(distinct(var.azs)) == length(var.azs)
    error_message = "Use two or three distinct availability zones."
  }
}

variable "enable_nat" {
  description = "Give private subnets outbound internet access through NAT gateways."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "One shared NAT gateway (cheaper) instead of one per AZ (survives an AZ outage)."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Retention for VPC flow logs."
  type        = number
  default     = 365
}

variable "kms_key_arn" {
  description = "KMS key that encrypts the flow-log group."
  type        = string
}
