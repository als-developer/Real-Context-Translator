variable "environment" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "ecs_security_group_id" {
  type = string
}

variable "alb_target_group_arn" {
  type = string
}

# API Service Variables
variable "api_service_name" {
  type = string
}

variable "api_container_image" {
  type = string
}

variable "api_container_port" {
  type = number
  default = 8000
}

variable "api_desired_count" {
  type = number
  default = 3
}

variable "api_max_capacity" {
  type = number
  default = 10
}

variable "api_min_capacity" {
  type = number
  default = 2
}

variable "api_cpu" {
  type = number
  default = 1024
}

variable "api_memory" {
  type = number
  default = 2048
}

# Worker Service Variables
variable "worker_service_name" {
  type = string
}

variable "worker_container_image" {
  type = string
}

variable "worker_desired_count" {
  type = number
  default = 2
}

variable "worker_cpu" {
  type = number
  default = 2048
}

variable "worker_memory" {
  type = number
  default = 4096
}

# Secrets and Configuration
variable "database_url" {
  type = string
  sensitive = true
}

variable "redis_url" {
  type = string
  sensitive = true
}

variable "stripe_secret_arn" {
  type = string
}

variable "openai_secret_arn" {
  type = string
}

variable "aws_region" {
  type = string
}
