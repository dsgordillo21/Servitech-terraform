resource "aws_s3_bucket" "frontend" {
  bucket_prefix = "${local.name_prefix}-frontend-"

  tags = {
    Name = "${local.name_prefix}-frontend"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${local.name_prefix}-frontend"
  description                       = "Acceso firmado al frontend privado de ServiTech"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "Frontend del MVP de ServiTech"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "frontend-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    target_origin_id       = "frontend-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # Archivos sin version en el nombre: revalidar en navegador y hasta 60 s en CDN.
    min_ttl     = 0
    default_ttl = 60
    max_ttl     = 300

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontReadOnly"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.frontend.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
        }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

resource "aws_s3_object" "index" {
  bucket        = aws_s3_bucket.frontend.id
  key           = "index.html"
  source        = "${path.module}/../frontend/index.html"
  source_hash   = filemd5("${path.module}/../frontend/index.html")
  content_type  = "text/html; charset=utf-8"
  cache_control = "public, max-age=0, s-maxage=60, must-revalidate"

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.frontend]
}

resource "aws_s3_object" "styles" {
  bucket        = aws_s3_bucket.frontend.id
  key           = "styles.css"
  source        = "${path.module}/../frontend/styles.css"
  source_hash   = filemd5("${path.module}/../frontend/styles.css")
  content_type  = "text/css; charset=utf-8"
  cache_control = "public, max-age=0, s-maxage=60, must-revalidate"

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.frontend]
}

locals {
  frontend_app_js = replace(
    file("${path.module}/../frontend/app.js"),
    "API_URL_PENDIENTE",
    aws_api_gateway_stage.dev.invoke_url
  )
}

resource "aws_s3_object" "app" {
  bucket        = aws_s3_bucket.frontend.id
  key           = "app.js"
  content       = local.frontend_app_js
  source_hash   = md5(local.frontend_app_js)
  content_type  = "text/javascript; charset=utf-8"
  cache_control = "public, max-age=0, s-maxage=60, must-revalidate"

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.frontend]
}
