resource "aws_s3_bucket" "s3_site_bucket" {
  bucket = var.domainName
  tags = {
    Environment        = var.SiteTags
  }
}

resource "aws_s3_bucket_public_access_block" "s3_site_access_block" {
  bucket = aws_s3_bucket.s3_site_bucket.id

  block_public_acls         = true
  block_public_policy       = true
  restrict_public_buckets   = true
  ignore_public_acls        = true
}

# Uploads all files from the local "src/dist" directory to a specified AWS S3 bucket.
resource "aws_s3_object" "static_file" {
  for_each     = fileset(local.dist_dir, "**")
  bucket       = aws_s3_bucket.s3_site_bucket.id
  key          = each.key
  source       = "${local.dist_dir}/${each.value}"
  content_type = lookup(local.content_types, regex("\\.[^.]+$", each.value), null)
  etag         = filemd5("${local.dist_dir}/${each.value}")
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.s3_site_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }
}

data "aws_caller_identity" "current" {
}


resource "aws_s3_bucket_policy" "web" {
  bucket = aws_s3_bucket.s3_site_bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}