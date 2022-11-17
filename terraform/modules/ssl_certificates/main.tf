# Unvalidated SSL certificates for one or more base domains

variable "primary_domain" {
  description = "For production this would be communities.gov.uk"
  type        = string
}

variable "secondary_domains" {
  type    = list(string)
  default = []
}

locals {
  all_domains = concat([var.primary_domain], var.secondary_domains)
  subdomains = {
    delta      = "delta"
    api        = "api.delta"
    keycloak   = "auth.delta"
    cpm        = "cpm"
    jaspersoft = "reporting"
  }
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

resource "aws_acm_certificate" "cloudfront_certs" {
  for_each = local.subdomains
  provider = aws.us-east-1

  domain_name               = "${each.value}.${var.primary_domain}"
  subject_alternative_names = [for domain in local.all_domains : "${each.value}.${domain}"]
  validation_method         = "DNS"
}

output "cloudfront_cert_arns" {
  value = { for key, subdomain in local.subdomains : key => aws_acm_certificate.cloudfront_certs[key].arn }
}

resource "aws_acm_certificate" "alb_certs" {
  for_each = local.subdomains

  domain_name               = "${each.value}.${var.primary_domain}"
  subject_alternative_names = [for domain in local.all_domains : "${each.value}.${domain}"]
  validation_method         = "DNS"
}

output "alb_cert_arns" {
  value = { for key, subdomain in local.subdomains : key => aws_acm_certificate.alb_certs[key].arn }
}

output "required_validation_records" {
  value = [for record in toset(flatten([
    [for cert in aws_acm_certificate.cloudfront_certs : cert.domain_validation_options],
    [for cert in aws_acm_certificate.alb_certs : cert.domain_validation_options],
    ])) : {
    record_name  = record.resource_record_name
    record_type  = record.resource_record_type
    record_value = record.resource_record_value
  }]
}
