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
resource "aws_iam_role_policy_attachment" "codedeploy" {
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

resource "aws_iam_role" "lambda" {
  name = "${var.PROJECT}-lambda-codedeploy-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda" {
  name = "${var.PROJECT}-lambda-codedeploy-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "codedeploy:CreateDeployment"
        ],
        Resource = "*"
      }
    ]
  })
}

###########################
# Trigger Deployment
###########################
resource "null_resource" "zip_lambda" {
  provisioner "local-exec" {
    command = "zip trigger_ecr_push.zip trigger_ecr_push.py"
    working_dir = "${path.module}"
  }
}
resource "aws_lambda_function" "trigger_codedeploy" {
  filename         = "trigger_ecr_push.zip"
  function_name    = "${var.PROJECT}-trigger-codedeploy-deployment"
  role             = aws_iam_role.lambda.arn
  handler          = "trigger_ecr_push.lambda_handler"
  runtime          = "python3.8"
  source_code_hash = filebase64sha256("trigger_ecr_push.zip")

  environment {
    variables = {
      CODEDEPLOY_APPLICATION_NAME = "${aws_codedeploy_app.app.name}"
      CODEDEPLOY_DEPLOYMENT_GROUP = "${aws_codedeploy_deployment_group.group.deployment_group_name}"
      ECR_URL = "${aws_ecr_repository.main.repository_url}"
    }
  }

  depends_on = [ null_resource.zip_lambda ]
}

resource "aws_cloudwatch_event_rule" "ecr_image_push" {
  name        = "${var.PROJECT}-ecr-image-push-event"
  description = "${var.PROJECT} App: Trigger Lambda on ECR image push"
  event_pattern = jsonencode({
    "source": ["aws.ecr"],
    "detail-type": ["ECR Image Action"],
    "detail": {
      "action-type": ["PUSH"],
      "repository-name": ["${aws_ecr_repository.main.name}"]
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.ecr_image_push.name
  target_id = "triggerLambda"
  arn       = aws_lambda_function.trigger_codedeploy.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger_codedeploy.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecr_image_push.arn
}