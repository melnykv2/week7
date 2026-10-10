resource "aws_lb" "alb" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]
  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "alb-target-group" {
  name        = "${var.project_name}-target-group"
  vpc_id      = aws_vpc.app.id
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  health_check {
    path                = "/api/v1/status/"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  tags = {
    Name = "${var.project_name}-target-group"
  }
}

resource "aws_lb_listener" "alb-listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-target-group.arn
  }
}
