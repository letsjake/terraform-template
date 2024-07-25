#!/bin/bash
export REGION="${REGION}"
export ECR_URL="${ECR_URL}"
export HOST_PORT="${HOST_PORT}"
export CONTAINER_PORT="${CONTAINER_PORT}"

# Install updates and necessary packages
sudo yum update -y
sudo yum install -y amazon-linux-extras docker

# Start Docker service
sudo service docker start
sudo usermod -a -G docker ec2-user
newgrp docker
# Install AWS CLI
sudo yum install -y aws-cli

# Log in to Amazon ECR
aws ecr get-login-password --region $REGION | sudo docker login --username AWS --password-stdin $ECR_URL

# Pull the Docker image from ECR
sudo docker pull $ECR_URL

# Run the Docker container
sudo docker run -d -p $CONTAINER_PORT:$CONTAINER_PORT $ECR_URL
