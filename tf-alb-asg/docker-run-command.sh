#!/bin/bash
# Install updates and necessary packages
sudo yum update -y
sudo yum install -y amazon-linux-extras docker

# Start Docker service
sudo service docker start
sudo usermod -a -G docker ec2-user
newgrp docker
# Install AWS CLI
sudo yum install -y aws-cli

# Set AWS credentials (replace with your actual keys)
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

# Log in to Amazon ECR
aws ecr get-login-password --region $REGION | sudo docker login --username AWS --password-stdin $ECR_URL

# Pull the Docker image from ECR
sudo docker pull $ECR_URL

# Run the Docker container
sudo docker run -d -p $HOST_PORT:$CONTAINER_PORT $ECR_URL
