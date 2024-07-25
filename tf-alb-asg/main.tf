terraform {
  required_version = "~> 1.9.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30.0"
    }
  }
}

provider "aws" {
  region = var.REGION

  default_tags {
    tags = var.DEFAULT_TAGS
  }
}

###########################
# VPC
###########################
# ref: https://github.com/terraform-aws-modules/terraform-aws-vpc
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.9.0"

  name = "${var.PROJECT}-vpc"
  cidr = "172.31.0.0/16"

  azs                  = ["apne2-az1", "apne2-az2"]
  public_subnets       = ["172.31.4.0/24", "172.31.5.0/24"] 
  private_subnets      = ["172.31.6.0/24", "172.31.7.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true
}

###########################
# Image & AutoScaling
###########################
data "aws_ami" "amazon-linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-minimal-hvm-*-x86_64-ebs"]
  }
}

resource "aws_launch_template" "app" {
  name_prefix     = "${var.PROJECT}-"
  # name            = "${var.PROJECT}-template"

  image_id        = data.aws_ami.amazon-linux.id
  instance_type   = "t3.small"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ecr_profile.name
  }

  user_data       = base64encode(templatefile("${path.module}/docker-run-command.sh", {
    REGION                  = var.REGION
    ECR_URL                 = aws_ecr_repository.main.repository_url
    HOST_PORT               = var.HOST_PORT
    CONTAINER_PORT           = var.CONTAINER_PORT
  }))

  key_name        = var.KEYPAIR_NAME 
  lifecycle {
    create_before_destroy = true
  }
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.instance.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = var.DEFAULT_TAGS
  }
}

resource "aws_autoscaling_group" "app" {
  name                 = var.PROJECT
  min_size             = 1
  max_size             = 2
  desired_capacity     = 2
  vpc_zone_identifier  = module.vpc.private_subnets
  target_group_arns    = [aws_lb_target_group.app.arn]

  health_check_type    = "ELB"

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
  tag {
    key                 = "name"
    value               = var.PROJECT
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_attachment" "app" {
  autoscaling_group_name = aws_autoscaling_group.app.id
  lb_target_group_arn   = aws_lb_target_group.app.arn
  depends_on             = [aws_autoscaling_group.app, aws_lb_target_group.app]
}

###########################
# Load Balancer, Security Group & Related parts
###########################
resource "aws_lb" "app" {
  name               = "${var.PROJECT}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.PROJECT}-app"
  port     = var.CONTAINER_PORT
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  target_type = "instance"
  load_balancing_algorithm_type = "round_robin"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = var.CONTAINER_PORT
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 10
  
  }
}

resource "aws_security_group" "instance" {
  name    = "${var.PROJECT}-instance"
  #For SSH 
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  ingress {
    description     = "Traffic from ALB to EC2 instances"
    from_port       = var.CONTAINER_PORT
    to_port         = var.CONTAINER_PORT
    protocol        = "tcp"
    security_groups = [aws_security_group.lb.id]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group" "lb" {
  name   = "${var.PROJECT}-lb"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = module.vpc.vpc_id
}

##############################
# IAM
##############################
resource "aws_iam_role" "ec2_ecr_access_role" {
  name = "${var.PROJECT}-ec2-ecr-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecr_access_policy" {
  name = "${var.PROJECT}-ecr-access-policy"
  role = aws_iam_role.ec2_ecr_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_ecr_profile" {
  name = "${var.PROJECT}-ec2-ecr-profile"
  role = aws_iam_role.ec2_ecr_access_role.name
}

###############################
# Outputs
###############################
output "lb_endpoint" {
  value = "http://${aws_lb.app.dns_name}"
}

output "application_endpoint" {
  value = "http://${aws_lb.app.dns_name}/"
}

output "ec2_autoscaling_group_name" {
  value = aws_autoscaling_group.app.name
}