import boto3
import json
import os

eventbridge = boto3.client("events", region_name="eu-west-2")

slack_message = os.environ["MESSAGE"]
detail = json.dumps({"slackMessage": slack_message})
eventbridge.put_events(
    Entries=[{'Source': 'DiagramTerraformDeploy', 'DetailType': 'DR2DevMessage', 'Detail': detail}]
)
