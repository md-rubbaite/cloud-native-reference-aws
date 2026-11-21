output "load_balancer_dns_name" {
  description = "Point your DNS record (CNAME or alias) here."
  value       = module.service.load_balancer_dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "deploy_role_arn" {
  description = "role-to-assume for aws-actions/configure-aws-credentials."
  value       = module.deploy_role.role_arn
}

output "ecs_cluster_name" {
  value = module.service.cluster_name
}

output "ecs_service_name" {
  value = module.service.service_name
}

output "database_address" {
  value = module.database.address
}

output "nat_gateway_count" {
  value = module.network.nat_gateway_count
}
