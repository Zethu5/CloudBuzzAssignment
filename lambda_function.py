import os
import json
import boto3


def send_email_notification(subject, message):
    client = boto3.client("sns")
    sns_arn = os.environ.get("SNS_EMAIL_ARN")

    client.publish(TopicArn=sns_arn, Message=message, Subject=subject)


def lambda_handler(event, context):
    result = int(event["num1"]) + int(event["num2"])
    message = f"The result was: {result}"
    subject = "[FUNCTION WAS USED] sum_two_nums"
    send_email_notification(subject, message)

    return json.dumps({"statusCode": 200, "result": result})
