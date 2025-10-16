# Launch Template for Public Instances
# -----------------------
resource "aws_launch_template" "public_web_lt" {
  name_prefix   = "public-web-"
  image_id      = "ami-0360c520857e3138f"
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt update -y
              apt install -y apache2
              systemctl start apache2
              echo "Hello from Public Instance" > /var/www/html/index.html
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "public-web-instance"
    }
  }
}

# -----------------------
# ALB + ASG for Public Instances
# -----------------------
resource "aws_lb" "public_alb" {
  name               = "public-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = [aws_subnet.public_1a.id, aws_subnet.public_1b.id]
}

resource "aws_lb_target_group" "public_tg" {
  name     = "public-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "public_http" {
  load_balancer_arn = aws_lb.public_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.public_tg.arn
  }
}

resource "aws_autoscaling_group" "public_web_asg" {
  name                = "public-web-asg"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = [aws_subnet.public_1a.id, aws_subnet.public_1b.id]

  target_group_arns = [aws_lb_target_group.public_tg.arn]

  launch_template {
    id      = aws_launch_template.public_web_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "public-web-instance"
    propagate_at_launch = true
  }
}

