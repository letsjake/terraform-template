import json
from os import getenv
import boto3

def lambda_handler(event, context):
    # Extract repository name and image tag from the ECR event
    detail = event['detail']
    repository_name = detail['repository-name']
    image_tag = detail['image-tag']

    codedeploy_application_name = getenv('CODEDEPLOY_APPLICATION_NAME')
    codedeploy_deployment_group_name = getenv('CODEDEPLOY_DEPLOYMENT_GROUP_NAME')
    ecr_url = getenv('ECR_URL')
    
    # Initialize CodeDeploy client
    codedeploy_client = boto3.client('codedeploy')

    # Create a new deployment
    response = codedeploy_client.create_deployment(
        applicationName=codedeploy_application_name,
        deploymentGroupName=codedeploy_deployment_group_name,
        revision={
            'revisionType': 'AppSpecContent',
            'appSpecContent': {
                'content': json.dumps({
                    "version": 0.0,
                    "Resources": [
                        {
                            "Files": {
                                "Source": f"docker://{ecr_url}",
                                "Destination": "/usr/src/app"
                            }
                        }
                    ]
                }),
                'sha256': ''  # Optional: provide sha256 hash for integrity, can be left empty if not used
            }
        }
    )

    return {
        'statusCode': 200,
        'body': json.dumps('Deployment triggered successfully!')
    }