provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

# Non sensitive
# tfsec:ignore:aws-sns-enable-topic-encryption
resource "aws_sns_topic" "alarm_sns_topic" {
  name         = "metric-alarms-${var.environment}"
  display_name = "Notifications for change in metric alarm status"
}

resource "aws_sns_topic_subscription" "alarm_sns_topic" {
  for_each = toset(var.alarm_sns_topic_emails)

  topic_arn = aws_sns_topic.alarm_sns_topic.arn
  protocol  = "email"
  endpoint  = each.value
}

# Non sensitive
# tfsec:ignore:aws-sns-enable-topic-encryption
resource "aws_sns_topic" "alarm_sns_topic_global" {
  # Note that this topic is meant for "Global" services - by convention, these
  # services are located in us-east-1, so that's where we need to create the SNS
  # topic. Alarms cannot be connected cross-regionally so we need a duplicate topic
  # in the region that they will exist.
  provider     = aws.us-east-1
  name         = "metric-alarms-${var.environment}"
  display_name = "Notifications for change in metric alarm status"
}

resource "aws_sns_topic_subscription" "alarm_sns_topic_global" {
  provider = aws.us-east-1

  for_each = toset(var.alarm_sns_topic_emails)

  topic_arn = aws_sns_topic.alarm_sns_topic_global.arn
  protocol  = "email"
  endpoint  = each.value
}

# tfsec:ignore:aws-sns-enable-topic-encryption
resource "aws_sns_topic" "security_sns_topic" {
  name         = "security-alarms-${var.environment}"
  display_name = "Notifications for change in security status"
}

resource "aws_sns_topic_subscription" "security_sns_topic" {
  for_each = toset(var.security_sns_topic_emails)

  topic_arn = aws_sns_topic.security_sns_topic.arn
  protocol  = "email"
  endpoint  = each.value
}

# Non sensitive
# tfsec:ignore:aws-sns-enable-topic-encryption
resource "aws_sns_topic" "security_sns_topic_global" {
  # Note that this topic is meant for "Global" services - by convention, these
  # services are located in us-east-1, so that's where we need to create the SNS
  # topic. Alarms cannot be connected cross-regionally so we need a duplicate topic
  # in the region that they will exist.
  provider     = aws.us-east-1
  name         = "security-alarms-${var.environment}"
  display_name = "Notifications for change in security status"
}

resource "aws_sns_topic_subscription" "security_sns_topic_global" {
  provider = aws.us-east-1

  for_each = toset(var.security_sns_topic_emails)

  topic_arn = aws_sns_topic.security_sns_topic_global.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_sns_topic_policy" "allow_guard_duty_events" {
  arn    = aws_sns_topic.security_sns_topic.arn
  policy = data.aws_iam_policy_document.allow_guard_duty_events.json
}

data "aws_iam_policy_document" "allow_guard_duty_events" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.security_sns_topic.arn]
  }
}
