#!/bin/bash
echo "=======User data from AWS launch template...======"
export REGION=${REGION}
export ECR_URL=${ECR_URL}
export HOST_PORT=${HOST_PORT}
export CONTAINER_PORT=${CONTAINER_PORT}

# Install updates and necessary packages
sudo yum update -y
sudo yum install -y amazon-linux-extras docker ruby wget

# AWS CodeDeploy agent installation
sudo wget https://aws-codedeploy-$REGION.s3.$REGION.amazonaws.com/latest/install -P /tmp
chmod +x /tmp/install
sudo /tmp/install auto
sudo service codedeploy-agent start

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

# kill the existing container
CONTAINER_ID=$(sudo docker ps -q --filter ancestor=$ECR_URL)
if [ -z "$CONTAINER_ID" ]; then
    echo "No running container found"
else
    echo "Stopping and removing container: $CONTAINER_ID"
    docker stop $CONTAINER_ID
    docker rm -f $CONTAINER_ID
    echo "Container removed successfully: $CONTAINER_ID"
fi

# Run the Docker container
sudo docker run -d -p $CONTAINER_PORT:$CONTAINER_PORT $ECR_URL
