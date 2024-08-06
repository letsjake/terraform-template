#!/bin/bash
echo "=======install.sh from CodeDeploy...======"
export REGION=ap-northeast-2
export ECR_URL=343475135657.dkr.ecr.ap-northeast-2.amazonaws.com/learn-terraform:latest
export HOST_PORT=80
export CONTAINER_PORT=5000

# Install updates and necessary packages
echo "log:: 1. Installing updates and necessary packages..."
sudo yum update -y
sudo yum install -y amazon-linux-extras docker ruby wget unzip

# AWS CodeDeploy agent installation
echo "log:: 2. Installing AWS CodeDeploy agent..."
sudo wget https://aws-codedeploy-$REGION.s3.$REGION.amazonaws.com/latest/install -P /tmp
chmod +x /tmp/install
sudo /tmp/install auto
sudo service codedeploy-agent start

# Start Docker service
echo "log:: 3. Starting Docker service..."
sudo service docker start
sudo usermod -a -G docker ec2-user
newgrp docker
# Install AWS CLI
echo "log:: 4. Installing AWS CLI..."
sudo yum install -y aws-cli

# Log in to Amazon ECR
echo "log:: 5. Logging in to Amazon ECR..."
aws ecr get-login-password --region $REGION | sudo docker login --username AWS --password-stdin $ECR_URL

# Pull the Docker image from ECR
echo "log:: 6. Pulling the Docker image from ECR..."
sudo docker pull $ECR_URL