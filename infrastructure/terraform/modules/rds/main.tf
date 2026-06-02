# DB Subnet Group
resource "aws_db_subnet_group" "this" {
  name        = "rct-engine-db-subnet-${var.environment}"
  description = "RDS subnet group for RCT Engine"
  subnet_ids  = var.private_subnets
  
  tags = {
    Name = "rct-engine-db-subnet-${var.environment}"
  }
}

# Parameter Group
resource "aws_db_parameter_group" "this" {
  family = "postgres15"
  name   = "rct-engine-pg-${var.environment}"
  
  parameter {
    name  = "max_connections"
    value = "500"
  }
  
  parameter {
    name  = "shared_buffers"
    value = "256MB"
  }
  
  parameter {
    name  = "effective_cache_size"
    value = "768MB"
  }
  
  parameter {
    name  = "work_mem"
    value = "8MB"
  }
  
  parameter {
    name  = "maintenance_work_mem"
    value = "64MB"
  }
  
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }
  
  parameter {
    name  = "log_connections"
    value = "1"
  }
  
  parameter {
    name  = "log_disconnections"
    value = "1"
  }
  
  tags = {
    Name = "rct-engine-pg-params-${var.environment}"
  }
}

# RDS Instance
resource "aws_db_instance" "this" {
  identifier = "rct-engine-db-${var.environment}"
  
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.db_instance_class
  
  allocated_storage     = var.db_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_security_group_id]
  parameter_group_name   = aws_db_parameter_group.this.name
  
  backup_retention_period = var.backup_retention_days
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  
  copy_tags_to_snapshot = true
  deletion_protection   = var.environment == "production"
  
  skip_final_snapshot = var.environment != "production"
  final_snapshot_identifier = var.environment == "production" ? "rct-engine-db-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null
  
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  tags = {
    Name = "rct-engine-db-${var.environment}"
  }
}

# Read Replica for production
resource "aws_db_instance" "replica" {
  count = var.environment == "production" ? 1 : 0
  
  identifier = "rct-engine-db-replica-${var.environment}"
  
  replicate_source_db = aws_db_instance.this.identifier
  instance_class      = var.db_instance_class
  
  vpc_security_group_ids = [var.rds_security_group_id]
  
  backup_retention_period = 7
  
  tags = {
    Name = "rct-engine-db-replica-${var.environment}"
  }
}
