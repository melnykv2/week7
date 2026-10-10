module "security-group-alb" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"

  name        = "${var.project_name}-alb"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.app.id

  ingress_rules = {
    http = {
      from_port   = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTP from anywhere"
    }
  }

  egress_rules = {
    app = {
      from_port                    = 8000
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.security-group-ecs.id
      description                  = "Allow egress to port 8000"
    }
  }
  tags = {
    Name = "${var.project_name}-alb"
  }
}

module "security-group-ecs" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"

  name        = "${var.project_name}-ecs"
  description = "Security group for ECS"
  vpc_id      = aws_vpc.app.id

  ingress_rules = {
    app = {
      from_port                    = 8000
      ip_protocol                  = "tcp"
      description                  = "Allow ingress to port 8000"
      referenced_security_group_id = module.security-group-alb.id
    }
  }

  egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow all egress"
    }
  }
  tags = {
    Name = "${var.project_name}-ecs"
  }
}

module "security-group-db" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"

  name        = "${var.project_name}-db"
  description = "Security group for DB"
  vpc_id      = aws_vpc.app.id

  ingress_rules = {
    db = {
      from_port                    = 5432
      ip_protocol                  = "tcp"
      description                  = "Allow ingress to port 5432"
      referenced_security_group_id = module.security-group-ecs.id
    }
  }
  tags = {
    Name = "${var.project_name}-db"
  }
}
