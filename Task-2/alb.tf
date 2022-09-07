terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

data "aws_security_group" "private" {
  name = "private"
}
data "aws_subnet" "private" {
  count = 2
  tags = {
    "Name" = "SG-private${var.name}-${count.index + 1}"
  }
}
data "aws_subnet" "public" {
  count = 2
  tags = {
    "Name" = "SG-public${var.name}-${count.index + 1}"
  }
}
data "aws_vpc" "cp-vpc" {
  tags = {
    "Name" = "VPC-${var.name}"
  }
}
resource "aws_lb" "cp-alb" {
  count = 2
  name               = "cp-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [data.aws_security_group.private.id]
  subnets            = [[element((data.aws_subnet.private)[1].id)], [element((data.aws_subnet.public)[1].id)]]//["data.aws_subnet.private"[*].id]

  enable_deletion_protection = true

  access_logs {
    bucket  = "arn:aws:s3:::suhaasnandeesh-tf-backend"
    prefix  = "cp-alb"
    enabled = true
  }

  tags = {
    Environment = "production"
  }
}

# resource "aws_security_group" "private" {
#   # (resource arguments)
# }
# resource "aws_subnet" "private" {
#   # (resource arguments)
#   vpc_id      = aws_vpc.cp-vpc.id

# }
resource "aws_lb_target_group" "tg" {
  name        = "alb-tg"
  target_type = "alb"
  port        = 80
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.cp-vpc.id
}

resource "aws_lb_listener" "cp-alb" {
  count = 2
  load_balancer_arn = element((aws_lb.cp-alb)[*].arn, count.index)
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_lb_listener_rule" "static" {
  count = 2
  listener_arn = element((aws_lb_listener.cp-alb)[*].arn, count.index)
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }

  condition {
    path_pattern {
      values = ["/jenkins/*", "/jenkins"]
    }
  }

  condition {
    host_header {
      values = ["10.5.5.215"]
    }
  }

  condition {
    path_pattern {
      values = ["/app/*", "/app"]
    }
  }

  condition {
    host_header {
      values = ["10.5.5.26"]
    }
  }
}