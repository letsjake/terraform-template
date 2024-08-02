import json
from os import getenv
import boto3

def lambda_handler(event, context):
    # detail = event['detail']
    # repository_name = detail['repository-name']
    # image_tag = detail['image-tag']
    codedeploy_application_name = getenv('CODEDEPLOY_APPLICATION_NAME')
    codedeploy_deployment_group_name = getenv('CODEDEPLOY_DEPLOYMENT_GROUP_NAME')
    ecr_url = getenv('ECR_URL')
    
    codedeploy_client = boto3.client('codedeploy')
    try:
        response = codedeploy_client.create_deployment(
            applicationName=codedeploy_application_name,
            deploymentGroupName=codedeploy_deployment_group_name,
            deploymentConfigName='CodeDeployDefault.OneAtATime',
            revision={
                'revisionType': 'S3',
                's3Location': {
                    'bucket': getenv('S3_BUCKET'),
                    'key': 'appspec.zip',
                    'bundleType': 'zip',
                }
            },
            autoRollbackConfiguration={
                'enabled': True,
                'events': ['DEPLOYMENT_FAILURE']
            },
            deploymentStyle={
                'deploymentType': 'BLUE_GREEN',
                'deploymentOption': 'WITH_TRAFFIC_CONTROL'
            }
        )
        return {
            'statusCode': 200,
            'body': json.dumps('Deployment triggered successfully!')
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps(str(e))
        }