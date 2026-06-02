# Redis Subnet Group
resource "aws_elasticache_subnet_group" "this" {
  name        = "rct-engine-redis-subnet-${var.environment}"
  description = "Redis subnet group for RCT Engine"
  subnet_ids  = var.private_subnets
}

# Redis Parameter Group
resource "aws_elasticache_parameter_group" "this" {
  family = "redis7"
  name   = "rct-engine-redis-params-${var.environment}"
  
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }
  
  parameter {
    name  = "timeout"
    value = "3600"
  }
  
  parameter {
    name  = "tcp-keepalive"
    value = "300"
  }
}

# Redis Replication Group
resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "rct-engine-redis-${var.environment}"
  description          = "Redis cluster for RCT Engine"
  
  engine         = "redis"
  engine_version = "7.1"
  node_type      = var.node_type
  
  num_cache_clusters = var.num_cache_nodes
  port              = var.port
  
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [var.redis_security_group_id]
  parameter_group_name       = aws_elasticache_parameter_group.this.name
  
  automatic_failover_enabled = var.num_cache_nodes > 1
  multi_az_enabled           = var.num_cache_nodes > 1
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth.result
  
  snapshot_retention_limit = 7
  snapshot_window          = "04:00-05:00"
  
  maintenance_window = "sun:05:00-sun:06:00"
  
  tags = {
    Name = "rct-engine-redis-${var.environment}"
  }
}

# Random auth token
resource "random_password" "redis_auth" {
  length  = 32
  special = false
}

# CloudWatch metrics for Redis
resource "aws_cloudwatch_dashboard" "redis" {
  dashboard_name = "rct-engine-redis-${var.environment}"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", "CacheClusterId", aws_elasticache_replication_group.this.replication_group_id],
            ["AWS/ElastiCache", "DatabaseMemoryUsagePercentage", "CacheClusterId", aws_elasticache
