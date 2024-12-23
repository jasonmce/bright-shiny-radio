##### Creating a Random String #####
resource "random_string" "random" {
  length = 6
  special = false
  upper = false
}

##### Creating an S3 Bucket #####
resource "aws_s3_bucket" "html-bucket" {
  bucket = "radio-${random_string.random.result}"
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.html-bucket.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_policy" "public_read_access" {
  bucket = aws_s3_bucket.html-bucket.id

  policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": "*",
        "Action": [ "s3:*" ],
        "Resource": [
          "${aws_s3_bucket.html-bucket.arn}",
          "${aws_s3_bucket.html-bucket.arn}/*"
        ]
      }
    ]
  }
EOF
}

resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket = aws_s3_bucket.html-bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
