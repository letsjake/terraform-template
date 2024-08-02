#!/bin/bash
echo "=======deploy.sh from CodeDeploy...======"
export CONTAINER_PORT=5000
export ECR_URL=343475135657.dkr.ecr.ap-northeast-2.amazonaws.com/learn-terraform:latest
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