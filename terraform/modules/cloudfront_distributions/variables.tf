variable "base_domains" {
  type = list(string)
}

variable "environment" {
  type = string
}

variable "auth_waf_per_ip_rate_limit" {
  type        = number
  default     = 500
  description = "The per-IP rate limit enforced by AWS WAF in requests per five minutes for the auth service"
}

variable "waf_per_ip_rate_limit" {
  type        = number
  default     = 1000
  description = "The per-IP rate limit enforced by AWS WAF in requests per five minutes"
}

variable "login_ip_rate_limit" {
  type        = number
  default     = 100
  description = "The per-IP rate limit enforced by AWS WAF in requests per five minutes to the login page"
}

variable "apply_aws_shield" {
  type = bool
}

variable "waf_cloudwatch_log_expiration_days" {
  type = number
}

variable "cloudfront_access_s3_log_expiration_days" {
  type = number
}

variable "swagger_s3_log_expiration_days" {
  type = number
}

variable "delta" {
  type = object({
    alb = object({
      cloudfront_key = string
      dns_name       = string
    })
    domain = optional(object({
      aliases             = list(string)
      acm_certificate_arn = string
    }))
    # Leave null to disable restrictions
    geo_restriction_countries = optional(list(string))
    ip_allowlist              = optional(list(string))

    origin_read_timeout                       = optional(number)
    server_error_rate_alarm_threshold_percent = optional(number)
    client_error_rate_alarm_threshold_percent = optional(number)
  })
}

variable "api" {
  type = object({
    alb = object({
      cloudfront_key = string
      dns_name       = string
    })
    domain = optional(object({
      aliases             = list(string)
      acm_certificate_arn = string
    }))
    geo_restriction_countries = optional(list(string))
    ip_allowlist              = optional(list(string))

    server_error_rate_alarm_threshold_percent = optional(number)
    client_error_rate_alarm_threshold_percent = optional(number)
  })
}

variable "keycloak" {
  type = object({
    alb = object({
      cloudfront_key = string
      dns_name       = string
    })
    domain = optional(object({
      aliases             = list(string)
      acm_certificate_arn = string
    }))
    geo_restriction_countries  = optional(list(string))
    keycloak_path_ip_allowlist = optional(list(string))

    server_error_rate_alarm_threshold_percent = optional(number)
    client_error_rate_alarm_threshold_percent = optional(number)
  })
}

variable "cpm" {
  type = object({
    alb = object({
      cloudfront_key = string
      dns_name       = string
    })
    domain = optional(object({
      aliases             = list(string)
      acm_certificate_arn = string
    }))
    geo_restriction_countries = optional(list(string))
    ip_allowlist              = optional(list(string))

    origin_read_timeout                       = optional(number)
    server_error_rate_alarm_threshold_percent = optional(number)
    client_error_rate_alarm_threshold_percent = optional(number)
  })
}

variable "jaspersoft" {
  type = object({
    alb = object({
      cloudfront_key = string
      dns_name       = string
    })
    domain = optional(object({
      aliases             = list(string)
      acm_certificate_arn = string
    }))
    geo_restriction_countries = optional(list(string))
    ip_allowlist              = optional(list(string))

    server_error_rate_alarm_threshold_percent = optional(number)
    client_error_rate_alarm_threshold_percent = optional(number)
  })
}

variable "alarms_sns_topic_global_arn" {
  description = "SNS topic ARN to send alarm notifications to"
  type        = string
}

variable "wait_for_deployment" {
  type = bool
}

variable "security_sns_topic_global_arn" {
  description = "SNS topic ARN to send security notifications to"
  type        = string
}
