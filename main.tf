terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-central-1"
}

resource "aws_s3_bucket" "website_bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_object" "index_html" {
  key    = "index.html"
  bucket = aws_s3_bucket.website_bucket.id
  source = "website/index.html"
  etag = filemd5("website/index.html")
  content_type = "text/html"
}


resource "aws_s3_object" "error_html" {
  key    = "error_html"
  bucket = aws_s3_bucket.website_bucket.id
  source = "website/error.html"
  etag = filemd5("website/error.html")
  content_type = "text/html"
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Origin Access Identity for CloudFront Distribution"
}

resource "aws_cloudfront_distribution" "cloudfront_distribution" {
  origin {
    domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id = var.bucket_name

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled = true
  is_ipv6_enabled = true
  default_root_object = var.website_index_document

  default_cache_behavior {
       allowed_methods = ["GET", "HEAD"]
       cached_methods = ["GET", "HEAD"]
       target_origin_id = var.bucket_name

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
    }

    viewer_certificate {
      cloudfront_default_certificate = true
    }

    restrictions {
    geo_restriction {
      restriction_type = "none"  # Changed from geolocation_whitelist to geo_restriction
    }
  }


    tags = {
        Name = "CloudFront Distribution"
        Environment = "Dev"
    }
  }

resource "aws_s3_bucket_policy" "website_bucket_policy" {

bucket = aws_s3_bucket.website_bucket.id

policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:GetObject"
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.website_bucket.arn}/*"
        Principal = {
          CanonicalUser = aws_cloudfront_origin_access_identity.origin_access_identity.s3_canonical_user_id
        }
      }
    ]
  })
}
