resource "aws_lb" "gamehub" {
  name               = "gamehub_connect"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.lb_logs.id
    prefix  = "test-lb"
    enabled = true
  }

  tags = {
    Environment = "production"
  }
}

resource "aws_lb" "e" {
  name               = "example"
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id     = aws_subnet.example1.id
    allocation_id = aws_eip.example1.id
  }

  subnet_mapping {
    subnet_id     = aws_subnet.example2.id
    allocation_id = aws_eip.example2.id
  }
}
