output "api_endpoint" {
  description = "API Gateway endpoint"
  value       = "https://${module.cloudfront.cloudfront_domain_name}"
}

output "dashboard_url" {
  description = "Dashboard URL"
  value       = "https://dashboard.rct-engine.com"
}

output "rds_endpoint" {
  description = "RDS endpoint (sensitive)"
  value       = module.rds.rds_endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis endpoint"
  value       = module.redis.redis_endpoint
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.ecs_cluster_name
}

output "s3_assets_bucket" {
  description = "S3 assets bucket name"
  value       = aws_s3_bucket.assets.id
}
