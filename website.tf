#-------------------------------------------------------------#
# Reoute53 Domain
#-------------------------------------------------------------#

data "aws_route53_zone" "domain" {
  name         = var.hosted_zone
  private_zone = false
}

data "aws_acm_certificate" "cert" {
  domain   = coalesce(var.domain_name, "*.${var.hosted_zone}")
  provider = aws.aws_cloudfront
  statuses = ["ISSUED"]
}

resource "aws_route53_record" "route53_record" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

#-------------------------------------------------------------#
# S3 Bucket
#-------------------------------------------------------------#

resource "aws_s3_bucket" "bucket" {
  bucket = var.domain_name
  acl    = "private"
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }
  }
}

# resource "aws_s3_bucket_object" "website_files" {
#   for_each = fileset("${path.module}/web/static", "*")
#   bucket   = aws_s3_bucket.bucket.id
#   key      = each.value
#   source   = "${path.module}/web/static/${each.value}"
#   etag     = filemd5("${path.module}/web/static/${each.value}")
# }

#-------------------------------------------------------------#
# CloudFront
#-------------------------------------------------------------#

resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "cloudfront oai"
}

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = "s3-origin"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }
  origin {
    domain_name = trimprefix(aws_apigatewayv2_api.lambda.api_endpoint, "https://")
    origin_id   = "apigw-origin"
    origin_path = "/prod"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  default_root_object = "index.html"

  aliases = [var.domain_name]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "apigw-origin"

    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    default_ttl            = 0
    min_ttl                = 0
    max_ttl                = 0
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1"
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    error_caching_min_ttl = 30
    response_page_path    = "/404.html"
  }

  custom_error_response {
    error_code            = 403
    response_code         = 404
    error_caching_min_ttl = 30
    response_page_path    = "/404.html"
  }
}
