variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
}

variable "domain_name" {
  description = "Domain name for MNIST example"
  type        = string
}

variable "hosted_zone" {
  description = "Route53 hosted zone"
  type        = string
}
