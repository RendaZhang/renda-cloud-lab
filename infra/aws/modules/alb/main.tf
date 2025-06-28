resource "aws_lb_target_group" "demo" {
  count       = var.create ? 1 : 0
  name        = "tg-python-demo"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path = "/"
  }
}

resource "aws_lb" "demo" {
  count                      = var.create ? 1 : 0
  name                       = "alb-demo"
  load_balancer_type         = "application"
  subnets                    = var.public_subnet_ids
  security_groups            = [var.alb_sg_id]
  enable_deletion_protection = false
}

resource "aws_lb_listener" "http" {
  count             = var.create ? 1 : 0
  load_balancer_arn = aws_lb.demo[0].arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demo[0].arn
  }
}