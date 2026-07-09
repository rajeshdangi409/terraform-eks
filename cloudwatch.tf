resource "aws_cloudwatch_log_group" "eks_cluster_logs" {
  name              = "/aws/eks/learning-cluster/cluster"
  retention_in_days = 30

  tags = {
    Environment = "dev"
    Project     = "terraform-eks"
    ManagedBy   = "terraform"
  }
}

resource "aws_sns_topic" "eks_monitoring_alerts" {
  name = "eks-learning-cluster-alerts"
}

resource "aws_sns_topic_policy" "eks_monitoring_alerts_policy" {
  arn = aws_sns_topic.eks_monitoring_alerts.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudWatchToPublish"
        Effect    = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.eks_monitoring_alerts.arn
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "eks_alert_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.eks_monitoring_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "time_sleep" "wait_for_lb_webhook" {
  depends_on = [helm_release.aws_lb_controller]

  create_duration = "90s"
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name = aws_eks_cluster.my_cluster.name
  addon_name   = "amazon-cloudwatch-observability"

  depends_on = [aws_eks_node_group.my_nodes, time_sleep.wait_for_lb_webhook]
}

resource "aws_cloudwatch_dashboard" "eks_dashboard" {
  dashboard_name = "eks-learning-cluster-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "EKS Cluster Health"
          view    = "timeSeries"
          stacked = false
          region  = "ap-south-1"
          period  = 300
          stat    = "Average"
          metrics = [
            ["ContainerInsights", "cluster_failed_node_count", "ClusterName", aws_eks_cluster.my_cluster.name],
            ["ContainerInsights", "node_cpu_utilization", "ClusterName", aws_eks_cluster.my_cluster.name],
            ["ContainerInsights", "node_memory_utilization", "ClusterName", aws_eks_cluster.my_cluster.name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Pod Resource Usage"
          view    = "timeSeries"
          stacked = false
          region  = "ap-south-1"
          period  = 300
          stat    = "Average"
          metrics = [
            ["ContainerInsights", "pod_cpu_utilization", "ClusterName", aws_eks_cluster.my_cluster.name],
            ["ContainerInsights", "pod_memory_utilization", "ClusterName", aws_eks_cluster.my_cluster.name]
          ]
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "cluster_failed_nodes" {
  alarm_name          = "eks-learning-cluster-failed-nodes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "cluster_failed_node_count"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Alarm when the EKS cluster has failed nodes"
  treat_missing_data  = "notBreaching"
  dimensions = {
    ClusterName = aws_eks_cluster.my_cluster.name
  }
  alarm_actions = [aws_sns_topic.eks_monitoring_alerts.arn]
}

resource "null_resource" "sns_test_publish" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["powershell", "-NoProfile", "-Command"]
    command     = "& aws sns publish --region ap-south-1 --topic-arn '${aws_sns_topic.eks_monitoring_alerts.arn}' --message 'Test notification from Terraform for EKS monitoring setup' --subject 'EKS CloudWatch Test'"
  }
}

resource "aws_cloudwatch_metric_alarm" "node_high_cpu" {
  alarm_name          = "eks-learning-cluster-node-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alarm when node CPU usage exceeds 80%"
  treat_missing_data  = "notBreaching"
  dimensions = {
    ClusterName = aws_eks_cluster.my_cluster.name
  }
  alarm_actions = [aws_sns_topic.eks_monitoring_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "node_high_memory" {
  alarm_name          = "eks-learning-cluster-node-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Alarm when node memory usage exceeds 85%"
  treat_missing_data  = "notBreaching"
  dimensions = {
    ClusterName = aws_eks_cluster.my_cluster.name
  }
  alarm_actions = [aws_sns_topic.eks_monitoring_alerts.arn]
}
