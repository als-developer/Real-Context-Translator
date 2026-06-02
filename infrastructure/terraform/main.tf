# RCT-Engine Ultimate Infrastructure - Terraform Configuration
# Provider: AWS (can be adapted to Azure/GCP)

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  
  backend "s3" {
    bucket         = "rct-engine-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "rct-engine-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "rct-engine"
      ManagedBy   = "Terraform"
      CostCenter  = "engineering"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  environment     = var.environment
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  azs             = data.aws_availability_zones.available.names
}

# ECS Cluster
module "ecs" {
  source = "./modules/ecs"
  
  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  private_subnets  = module.vpc.private_subnets
  public_subnets   = module.vpc.public_subnets
  
  ecs_cluster_name = "rct-engine-cluster"
  
  # API Service Configuration
  api_service_name      = "rct-api"
  api_container_image   = "ghcr.io/rct-engine/api:latest"
  api_container_port    = 8000
  api_desired_count     = var.api_desired_count
  api_cpu               = 1024
  api_memory            = 2048
  
  # Worker Service Configuration
  worker_service_name    = "rct-worker"
  worker_container_image = "ghcr.io/rct-engine/worker:latest"
  worker_desired_count   = var.worker_desired_count
  worker_cpu             = 2048
  worker_memory          = 4096
}

# RDS Database
module "rds" {
  source = "./modules/rds"
  
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  private_subnets   = module.vpc.private_subnets
  
  db_name           = "rct_saas"
  db_username       = var.db_username
  db_password       = random_password.db_password.result
  db_instance_class = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  
  backup_retention_days = 30
  backup_window        = "03:00-04:00"
  maintenance_window   = "sun:04:00-sun:05:00"
}

# ElastiCache Redis
module "redis" {
  source = "./modules/redis"
  
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  
  node_type       = var.redis_node_type
  num_cache_nodes = 2
  port            = 6379
}

# Load Balancer
module "alb" {
  source = "./modules/alb"
  
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnets
  
  alb_name       = "rct-engine-alb"
  certificate_arn = var.certificate_arn
  
  target_group_name = "rct-api-tg"
  target_group_port = 8000
}

# CloudFront CDN
module "cloudfront" {
  source = "./modules/cloudfront"
  
  environment     = var.environment
  alb_dns_name    = module.alb.alb_dns_name
  alb_zone_id     = module.alb.alb_zone_id
  
  domain_name     = var.domain_name
  certificate_arn = var.certificate_arn
}

# S3 Assets Bucket
resource "aws_s3_bucket" "assets" {
  bucket = "rct-engine-assets-${var.environment}"
  
  tags = {
    Name = "RCT Engine Assets"
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Random password for database
resource "random_password" "db_password" {
  length  = 24
  special = false
}

# Outputs
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "rds_endpoint" {
  value = module.rds.rds_endpoint
  sensitive = true
}

output "redis_endpoint" {
  value = module.redis.redis_endpoint
}
