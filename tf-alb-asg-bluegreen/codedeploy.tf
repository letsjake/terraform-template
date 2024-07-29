resource "aws_codedeploy_app" "app" {
  compute_platform = "Server"
  name             = var.PROJECT
}

resource "aws_codedeploy_deployment_config" "config" {
  deployment_config_name = "${var.PROJECT}-config"
  compute_platform       = "Server"

  minimum_healthy_hosts {
    type  = "HOST_COUNT"
    value = 2
  }

  #   traffic_routing_config {
  #     type = "AllAtOnce"
  #   }
}

resource "aws_codedeploy_deployment_group" "group" {
  app_name               = aws_codedeploy_app.app.name
  deployment_group_name  = "${var.PROJECT}-group"
  service_role_arn       = aws_iam_role.codedeploy.arn
  deployment_config_name = aws_codedeploy_deployment_config.config.id
  autoscaling_groups     = [aws_autoscaling_group.app.name]

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  load_balancer_info {
    elb_info {
      name = aws_lb.app.name
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {

    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT" # reroute traffic immediately
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 360
    }

    green_fleet_provisioning_option {
      action = "COPY_AUTO_SCALING_GROUP"
    }
  }
}

###########################
# IAM Role for CodeDeploy
###########################
resource "aws_iam_role_policy_attachment" "example" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = data.aws_iam_policy.codedeploy.arn
}

resource "aws_iam_role" "codedeploy" {
  name = "${var.PROJECT}-codedeploy-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
}

# Pre-defined policy
data "aws_iam_policy" "codedeploy" {
  name        = "AWSCodeDeployRole"
}