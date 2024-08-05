resource "aws_codedeploy_app" "app" {
  compute_platform = "Server"
  name             = var.PROJECT
}

resource "aws_codedeploy_deployment_config" "config" {
  deployment_config_name = "${var.PROJECT}-config"
  compute_platform       = "Server"

  minimum_healthy_hosts {
    type  = "HOST_COUNT"
    value = 0
  }

    #NOTE: only works if compute_platform is non-server
    # traffic_routing_config {
    #   type = "AllAtOnce"
    # }
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
    target_group_info {
      name = aws_lb_target_group.app.name
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
      termination_wait_time_in_minutes = 1
    }

    green_fleet_provisioning_option {
      action = "COPY_AUTO_SCALING_GROUP"
    }
  }

  depends_on = [ aws_lb_listener.https ]
}

###########################
# IAM Role for CodeDeploy
###########################


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

data "aws_iam_policy" "codedeploy" {
  name = "AWSCodeDeployRole"
}
resource "aws_iam_role_policy_attachment" "codedeploy" {
  policy_arn = data.aws_iam_policy.codedeploy.arn
  role       = aws_iam_role.codedeploy.name
}

resource "aws_iam_role_policy" "codedeploy_additional" {
  name = "${var.PROJECT}-codedeploy-policy"
  role = aws_iam_role.codedeploy.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "iam:PassRole",
          "ec2:CreateTags",
          "ec2:RunInstances",
        ],
        "Resource" : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })
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
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = "*"
      }
    ]
  })
}

###########################
# Trigger Deployment
###########################

resource "null_resource" "zip_appspec" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command     = <<-EOT
      if [ -f appspec.zip ]; then
        rm appspec.zip
      fi
      zip -r appspec.zip appspec/appspec.yml appspec/scripts
      echo "appspec.zip created at $(pwd)/appspec.zip"
    EOT
    working_dir = path.module
  }
}

resource "aws_s3_bucket" "appspec" {
  bucket = "${var.PROJECT}-codedeploy-artifacts"

  lifecycle {
    prevent_destroy = false
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      aws s3 rm s3://${self.bucket} --recursive
    EOT
  }
}

resource "aws_s3_object" "appspec_zip" {
  bucket = aws_s3_bucket.appspec.id
  key    = "appspec.zip"
  source = "${path.module}/appspec.zip"
  
  depends_on = [null_resource.zip_appspec]
  
  # Add this to ensure the file exists before trying to upload
  provisioner "local-exec" {
    command = "test -f ${path.module}/appspec.zip || exit 1"
  }
}

resource "null_resource" "zip_lambda" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command     = <<-EOT
      if [ -f trigger_ecr_push.zip ]; then
        rm trigger_ecr_push.zip
      fi
      zip trigger_ecr_push.zip trigger_ecr_push.py
      echo "trigger_ecr_push.zip created at $(pwd)/trigger_ecr_push.zip"
    EOT
    working_dir = path.module
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
      S3_BUCKET                        = aws_s3_bucket.appspec.id
      CODEDEPLOY_APPLICATION_NAME      = "${aws_codedeploy_app.app.name}"
      CODEDEPLOY_DEPLOYMENT_GROUP_NAME = "${aws_codedeploy_deployment_group.group.deployment_group_name}"
      ECR_URL                          = "${aws_ecr_repository.main.repository_url}"
    }
  }

  depends_on = [null_resource.zip_lambda]
}

resource "aws_cloudwatch_event_rule" "ecr_image_push" {
  name        = "${var.PROJECT}-ecr-image-push-event"
  description = "${var.PROJECT} App: Trigger Lambda on ECR image push"
  event_pattern = jsonencode({
    "source" : ["aws.ecr"],
    "detail-type" : ["ECR Image Action"],
    "detail" : {
      "action-type" : ["PUSH"],
      "repository-name" : ["${aws_ecr_repository.main.name}"]
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
