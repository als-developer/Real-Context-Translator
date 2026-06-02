# ECS Cluster
resource "aws_ecs_cluster" "this" {
  name = var.ecs_cluster_name
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = {
    Name = "rct-engine-ecs-cluster-${var.environment}"
  }
}

# CloudWatch Log Group for API
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/rct-api-${var.environment}"
  retention_in_days = 30
  
  tags = {
    Name = "rct-engine-api-logs-${var.environment}"
  }
}

# CloudWatch Log Group for Worker
resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/rct-worker-${var.environment}"
  retention_in_days = 30
  
  tags = {
    Name = "rct-engine-worker-logs-${var.environment}"
  }
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_execution" {
  name = "rct-engine-ecs-execution-role-${var.environment}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_execution_ssm" {
  name = "rct-engine-ecs-execution-ssm"
  role = aws_iam_role.ecs_execution.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "secretsmanager:GetSecretValue"
        ]
        Resource = ["*"]
      }
    ]
  })
}

# Task Definition for API Service
resource "aws_ecs_task_definition" "api" {
  family                   = "rct-api-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.api_cpu
  memory                   = var.api_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_execution.arn
  
  container_definitions = jsonencode([
    {
      name  = "rct-api"
      image = var.api_container_image
      
      portMappings = [
        {
          containerPort = var.api_container_port
          protocol      = "tcp"
        }
      ]
      
      environment = [
        { name = "ENVIRONMENT", value = var.environment },
        { name = "DATABASE_URL", value = var.database_url },
        { name = "REDIS_URL", value = var.redis_url },
      ]
      
      secrets = [
        { name = "STRIPE_SECRET_KEY", valueFrom = var.stripe_secret_arn },
        { name = "OPENAI_API_KEY", valueFrom = var.openai_secret_arn },
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}

# API Service
resource "aws_ecs_service" "api" {
  name            = var.api_service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "rct-api"
    container_port   = var.api_container_port
  }
  
  deployment_controller {
    type = "ECS"
  }
  
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  
  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }
  
  tags = {
    Name = "rct-engine-api-service-${var.environment}"
  }
}

# Auto Scaling for API Service
resource "aws_appautoscaling_target" "api" {
  max_capacity       = var.api_max_capacity
  min_capacity       = var.api_min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "api_cpu" {
  name               = "rct-api-cpu-scaling-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api.resource_id
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api.service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Task Definition for Worker Service
resource "aws_ecs_task_definition" "worker" {
  family                   = "rct-worker-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.worker_cpu
  memory                   = var.worker_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_execution.arn
  
  container_definitions = jsonencode([
    {
      name  = "rct-worker"
      image = var.worker_container_image
      
      environment = [
        { name = "ENVIRONMENT", value = var.environment },
        { name = "DATABASE_URL", value = var.database_url },
        { name = "REDIS_URL", value = var.redis_url },
      ]
      
      secrets = [
        { name = "STRIPE_SECRET_KEY", valueFrom = var.stripe_secret_arn },
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.worker.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# Worker Service
resource "aws_ecs_service" "worker" {
  name            = var.worker_service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = var.worker_desired_count
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }
  
  deployment_controller {
    type = "ECS"
  }
  
  tags = {
    Name = "rct-engine-worker-service-${var.environment}"
  }
}
