# Security group for NLB
resource "aws_security_group" "lb_sg" {
  name   = "gamehub-nlb-sg"
  vpc_id = aws_vpc.gamehub.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gamehub-nlb-sg"
  }
}

# Retain the existing log bucket when tearing down this infrastructure.
removed {
  from = aws_s3_bucket.lb_logs

  lifecycle {
    destroy = false
  }
}

# The persistent bucket is used here but is no longer managed by this state.
data "aws_s3_bucket" "lb_logs" {
  bucket = "gamehub-nlb-logs-${data.aws_caller_identity.current.account_id}"
}

# S3 bucket policy to allow NLB to write logs
resource "aws_s3_bucket_policy" "lb_logs" {
  bucket = data.aws_s3_bucket.lb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "AWSLogDeliveryWrite"
    Statement = [
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = data.aws_s3_bucket.lb_logs.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${data.aws_s3_bucket.lb_logs.arn}/nlb-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })
}

# Network Load Balancer
resource "aws_lb" "gamehub" {
  name               = "gamehub-connect"
  internal           = false
  load_balancer_type = "network"
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  enable_deletion_protection = false

  depends_on = [aws_s3_bucket_policy.lb_logs]

  access_logs {
    bucket  = data.aws_s3_bucket.lb_logs.id
    prefix  = "nlb-logs"
    enabled = true
  }

  tags = {
    Environment = "production"
  }
}

# Target group for the NLB
resource "aws_lb_target_group" "gamehub" {
  name        = "gamehub-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = aws_vpc.gamehub.id
  target_type = "ip"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    port                = "80"
  }

  tags = {
    Name = "gamehub-tg"
  }
}

# Listener for the NLB
resource "aws_lb_listener" "gamehub" {
  load_balancer_arn = aws_lb.gamehub.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gamehub.arn
  }
}

data "aws_partition" "current" {}
data "aws_region" "current" {}
