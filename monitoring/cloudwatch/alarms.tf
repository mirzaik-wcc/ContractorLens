# ContractorLens CloudWatch Alarms Configuration
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
  
  tags = {
    Environment = var.environment
    Project     = "ContractorLens"
  }
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count = length(var.alert_email_addresses)
  
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email_addresses[count.index]
}

# High-Priority Alarms (Critical System Issues)
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.project_name}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors high 5xx error rate"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
  
  tags = {
    Priority = "Critical"
  }
}

resource "aws_cloudwatch_metric_alarm" "database_cpu_high" {
  alarm_name          = "${var.project_name}-database-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors high database CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
  
  tags = {
    Priority = "Critical"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_service_unhealthy" {
  alarm_name          = "${var.project_name}-ecs-service-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors ECS service health"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    ServiceName = aws_ecs_service.app.name
    ClusterName = aws_ecs_cluster.main.name
  }
  
  tags = {
    Priority = "Critical"
  }
}

resource "aws_cloudwatch_metric_alarm" "response_time_high" {
  alarm_name          = "${var.project_name}-response-time-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "This metric monitors high response times"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
  
  tags = {
    Priority = "High"
  }
}

# Medium-Priority Alarms (Performance Degradation)
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.project_name}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "This metric monitors high ECS CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    ServiceName = aws_ecs_service.app.name
    ClusterName = aws_ecs_cluster.main.name
  }
  
  tags = {
    Priority = "Medium"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.project_name}-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors high ECS memory utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    ServiceName = aws_ecs_service.app.name
    ClusterName = aws_ecs_cluster.main.name
  }
  
  tags = {
    Priority = "Medium"
  }
}

resource "aws_cloudwatch_metric_alarm" "database_connections_high" {
  alarm_name          = "${var.project_name}-database-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "15"
  alarm_description   = "This metric monitors high database connection count"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
  
  tags = {
    Priority = "Medium"
  }
}

# Custom Application Alarms
resource "aws_cloudwatch_metric_alarm" "estimate_api_errors" {
  alarm_name          = "${var.project_name}-estimate-api-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "EstimateAPIErrors"
  namespace           = "ContractorLens/API"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors estimate API errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  
  tags = {
    Priority = "High"
  }
}

resource "aws_cloudwatch_metric_alarm" "gemini_api_errors" {
  alarm_name          = "${var.project_name}-gemini-api-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "GeminiAPIErrors"
  namespace           = "ContractorLens/ML"
  period              = "300"
  statistic           = "Sum"
  threshold           = "3"
  alarm_description   = "This metric monitors Gemini API errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  
  tags = {
    Priority = "High"
  }
}

resource "aws_cloudwatch_metric_alarm" "gemini_api_latency_high" {
  alarm_name          = "${var.project_name}-gemini-api-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "GeminiAPILatency"
  namespace           = "ContractorLens/ML"
  period              = "300"
  statistic           = "Average"
  threshold           = "10000"  # 10 seconds
  alarm_description   = "This metric monitors high Gemini API latency"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  
  tags = {
    Priority = "Medium"
  }
}

# Business Metric Alarms
resource "aws_cloudwatch_metric_alarm" "low_estimate_generation" {
  alarm_name          = "${var.project_name}-low-estimate-generation"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "EstimatesGenerated"
  namespace           = "ContractorLens/Business"
  period              = "3600"  # 1 hour
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors low estimate generation rate"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching"
  
  tags = {
    Priority = "Low"
  }
}

# Log-based Alarms
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  name           = "${var.project_name}-error-count"
  log_group_name = aws_cloudwatch_log_group.app.name
  pattern        = "ERROR"
  
  metric_transformation {
    name      = "ErrorCount"
    namespace = "ContractorLens/Logs"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "log_errors" {
  alarm_name          = "${var.project_name}-log-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ErrorCount"
  namespace           = "ContractorLens/Logs"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors error log entries"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  tags = {
    Priority = "Medium"
  }
}

# Variables for alarm configuration
variable "alert_email_addresses" {
  description = "List of email addresses to send alerts to"
  type        = list(string)
  default     = ["devops@contractorlens.com"]
}