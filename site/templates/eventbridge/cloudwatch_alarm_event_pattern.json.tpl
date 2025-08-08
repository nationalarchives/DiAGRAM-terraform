{
  "source": [
    "aws.cloudwatch"
  ],
  "detail-type": [
    "CloudWatch Alarm State Change"
  ],
  "resources": ${cloudwatch_alarms},
  "detail": {
    "state": {
      "value": [
        "${state_value}"
      ]
    }
  }
}
