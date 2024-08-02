APP_NAME=learn-terraform
REGION=ap-northeast-2
ECR_URL=343475135657.dkr.ecr.$REGION.amazonaws.com/$APP_NAME

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URL
docker build --platform linux/amd64 -t $APP_NAME ../app
docker tag $APP_NAME:latest $ECR_URL:latest
docker push $ECR_URL:latest