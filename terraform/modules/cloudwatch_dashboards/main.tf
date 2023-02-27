module "dashboard" {
  source                     = "../cloudwatch_dashboard"
  dashboard_name             = var.delta_dashboard.dashboard_name
  alb_arn_suffix             = var.delta_dashboard.alb_arn_suffix
  cloudfront_alarms          = var.delta_dashboard.cloudfront_alarms
  cloudfront_distribution_id = var.delta_dashboard.cloudfront_distribution_id
  instance_metric_namespace  = var.delta_dashboard.instance_metric_namespace
}
