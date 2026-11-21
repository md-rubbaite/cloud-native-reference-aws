output "address" {
  value = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "database_name" {
  value = aws_db_instance.this.db_name
}

output "resource_id" {
  description = "Used to scope rds-db:connect permissions for IAM authentication."
  value       = aws_db_instance.this.resource_id
}

output "master_secret_arn" {
  description = "Secrets Manager secret holding the master credentials (for break-glass use only)."
  value       = try(aws_db_instance.this.master_user_secret[0].secret_arn, null)
}

output "security_group_id" {
  value = aws_security_group.this.id
}
