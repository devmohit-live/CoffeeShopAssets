// aws configuration
provider "aws" {
  region  = "ap-south-1"
}
//s3 bucket creation
 resource "aws_s3_bucket" "coffeeshop-task1" {
  bucket = "coffeeshop-task1"
  acl    = "private"
  tags = {
    Name = "Images Bucket"
  }
}
locals {
  s3_origin_id = "coffeeshop-task1"
}
//uploading files to s3
resource "aws_s3_bucket_object" "uploads" {
  for_each = fileset("./", "*")
  bucket = "coffeeshop-task1"
  key    = each.value
  source = "./${each.value}"
   depends_on = [aws_s3_bucket.coffeeshop-task1]
}
//creating cloudfront origin access identity
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Some comment"
  depends_on=[aws_s3_bucket.coffeeshop-task1]
}
// creating cloud distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [aws_s3_bucket_object.uploads]
  origin {
    domain_name = "${aws_s3_bucket.coffeeshop-task1.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
  enabled             = true
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

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
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "my cloudfront"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
// creating s3 bucket policy for cloudfront
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.coffeeshop-task1.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.coffeeshop-task1.arn}"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
}
resource "aws_s3_bucket_policy" "coffeeshop-task1-policy" {
  bucket = "${aws_s3_bucket.coffeeshop-task1.id}"
  policy = "${data.aws_iam_policy_document.s3_policy.json}"
}
// getting the cloudfront url for mail
output "cloudfrontdomain" {
 value = aws_cloudfront_distribution.s3_distribution.domain_name
}
