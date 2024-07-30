#################################################################################################
# This file describes the ECR resources: ECR repo, ECR policy, resources to build and push image
#################################################################################################

#Creation of the ECR repo
resource "aws_ecr_repository" "main" {
  name = var.PROJECT
  force_delete = true
  tags = var.DEFAULT_TAGS
}

#The ECR policy describes the management of images in the repo
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name
  policy     = local.ecr_policy
}

#This is the policy defining the rules for images in the repo
locals {
  ecr_policy = jsonencode({
    "rules" : [
      {
        "rulePriority" : 1,
        "description" : "Expire images older than 14 days",
        "selection" : {
          "tagStatus" : "any",
          "countType" : "sinceImagePushed",
          "countUnit" : "days",
          "countNumber" : 14
        },
        "action" : {
          "type" : "expire"
        }
      }
    ]
  })
}

#The commands below are used to build and push a docker image of the application in the app folder
locals {
  docker_login_command = "aws ecr get-login-password --region ${var.REGION} --profile default | docker login --username AWS --password-stdin ${var.AWS_ACCOUNT_ID}.dkr.ecr.${var.REGION}.amazonaws.com"
  docker_build_command = "docker build --platform linux/amd64 -t ${aws_ecr_repository.main.name} ../app"
  docker_tag_command   = "docker tag ${aws_ecr_repository.main.name}:latest ${var.AWS_ACCOUNT_ID}.dkr.ecr.${var.REGION}.amazonaws.com/${aws_ecr_repository.main.name}:latest"
  docker_push_command  = "docker push ${var.AWS_ACCOUNT_ID}.dkr.ecr.${var.REGION}.amazonaws.com/${aws_ecr_repository.main.name}:latest"
}

#This resource authenticates you to the ECR service
resource "null_resource" "docker_login" {
  provisioner "local-exec" {
    command = local.docker_login_command
  }
  triggers = {
    "run_at" = timestamp()
  }
  depends_on = [aws_ecr_repository.main]
}

#This resource builds the docker image from the Dockerfile in the app folder
resource "null_resource" "docker_build" {
  provisioner "local-exec" {
    command = local.docker_build_command
  }
  triggers = {
    "run_at" = timestamp()
  }
  depends_on = [null_resource.docker_login]
}

#This resource tags the image 
resource "null_resource" "docker_tag" {
  provisioner "local-exec" {
    command = local.docker_tag_command
  }
  triggers = {
    "run_at" = timestamp()
  }
  depends_on = [null_resource.docker_build]
}

#This resource pushes the docker image to the ECR repo
resource "null_resource" "docker_push" {
  provisioner "local-exec" {
    command = local.docker_push_command
  }
  triggers = {
    "run_at" = timestamp()
  }
  depends_on = [null_resource.docker_tag]
}

output "ecr_url" {
  value = aws_ecr_repository.main.repository_url
}
