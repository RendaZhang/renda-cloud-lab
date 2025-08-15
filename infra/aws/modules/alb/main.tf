// ---------------------------
// Application Load Balancer 相关资源
// 包含目标组、负载均衡器及监听器配置
// ---------------------------

resource "aws_lb_target_group" "demo" {
  count       = var.create ? 1 : 0 # 当 create 为 true 时创建目标组
  name        = "tg-python-demo"   # 目标组名称
  port        = 80                 # 后端服务端口
  protocol    = "HTTP"             # 后端协议
  vpc_id      = var.vpc_id         # 所属 VPC
  target_type = "ip"               # 以 IP 作为注册目标
  health_check {
    path = "/" # 健康检查路径
  }
}

resource "aws_lb" "demo" {
  count                      = var.create ? 1 : 0    # 是否创建 ALB
  name                       = "alb-demo"            # ALB 名称
  load_balancer_type         = "application"         # 类型：应用型负载均衡
  subnets                    = var.public_subnet_ids # 放置在公有子网
  security_groups            = [var.alb_sg_id]       # 关联安全组
  enable_deletion_protection = false                 # 关闭删除保护
}

resource "aws_lb_listener" "http" {
  count             = var.create ? 1 : 0 # 是否创建监听器
  load_balancer_arn = aws_lb.demo[0].arn # 关联的 ALB
  port              = 80                 # 监听端口
  protocol          = "HTTP"             # 监听协议
  default_action {
    type             = "forward" # 默认转发到目标组
    target_group_arn = aws_lb_target_group.demo[0].arn
  }
}
