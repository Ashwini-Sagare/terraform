import boto3

def lambda_handler(event, context):
    # Initialize EC2 client
    ec2_client = boto3.client('ec2')
    
    # Get list of running instances
    instances = ec2_client.describe_instances(
        Filters=[
            {
                'Name': 'instance-state-name',
                'Values': ['running']
            }
        ]
    )['Reservations']
    
    # Stop each running instance
    for reservation in instances:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            ec2_client.stop_instances(InstanceIds=[instance_id])
            print(f"Stopped instance {instance_id}")
    
    # Send notification
    sns_client = boto3.client('sns')
    sns_client.publish(
        TopicArn='arn:aws:sns:us-east-1:521492420587:EC2_Stop_Notification',
        Message='EC2 instances have been stopped successfully'
    )

