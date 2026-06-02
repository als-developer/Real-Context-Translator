variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "rds_security_group_id" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
  sensitive = true
}

variable "db_password" {
  type = string
  sensitive = true
}

variable "db_instance_class" {
  type = string
  default = "db.r6g.large"
}

variable "db_allocated_storage" {
  type = number
  default = 100
}

variable "backup_retention_days" {
  type = number
  default = 30
}

variable "backup_window" {
  type = string
  default = "03:00-04:00"
}

variable "maintenance_window" {
  type = string
  default = "sun:04:00-sun:05:00"
}
