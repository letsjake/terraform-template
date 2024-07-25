terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.38"
    }
  }
  required_version = ">= 0.15"
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
  version = "2.77.0"

  name = "main-vpc"
  cidr = "172.31.0.0/16"

  azs                  = ["apne2-az1", "apne2-az2"]
  public_subnets       = ["172.31.4.0/24", "172.31.5.0/24"] 
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
    values = ["amzn-ami-2018.03.20230627-amazon-ecs-optimized"]
  }
}

resource "aws_launch_configuration" "app" {
  name_prefix     = "${var.PROJECT}-"
  image_id        = data.aws_ami.amazon-linux.id
  instance_type   = "t2.small"
  user_data       = templatefile("${path.module}/docker_run_template.sh", {
    AWS_ACCESS_KEY_ID       = var.AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY   = var.AWS_SECRET_ACCESS_KEY
    ECR_URL                 = var.ECR_URL
    HOST_PORT               = var.HOST_PORT
    CONTAINER_PORT           = var.CONTAINER_PORT
  })
  security_groups = [aws_security_group.instance.id]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app" {
  name                 = var.PROJECT
  min_size             = 1
  max_size             = 2
  desired_capacity     = 2
  launch_configuration = aws_launch_configuration.app.name
  vpc_zone_identifier  = module.vpc.public_subnets

  health_check_type    = "ELB"

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
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  target_type = "instance"
  load_balancing_algorithm_type = "round_robin"
}

resource "aws_security_group" "instance" {
  name = "${var.PROJECT}-instance"
  ingress {
    from_port       = 80
    to_port         = 80
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
  name = "${var.PROJECT}-lb"
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