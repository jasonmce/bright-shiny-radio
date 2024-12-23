
##### Upload all the files present under HTML folder to the S3 bucket #####
locals {
  dist_dir    = "${path.module}/../html"
  module_name = basename(abspath(path.module))

  content_types = {
    ".html" : "text/html",
    ".css" : "text/css",
    ".js" : "application/javascript",
    ".json" : "application/json",
    ".xml" : "application/xml",
    ".jpg" : "image/jpeg",
    ".jpeg" : "image/jpeg",
    ".png" : "image/png",
    ".gif" : "image/gif",
    ".svg" : "image/svg+xml",
    ".webp" : "image/webp",
    ".ico" : "image/x-icon",
    ".woff" : "font/woff",
    ".woff2" : "font/woff2",
    ".ttf" : "font/ttf",
    ".eot" : "application/vnd.ms-fontobject",
    ".otf" : "font/otf"
  }
}

resource "aws_s3_object" "upload_object" {
  for_each      = fileset("html/", "*")
  bucket        = aws_s3_bucket.html-bucket.id
  key           = each.value
  source        = "html/${each.value}"
  etag          = filemd5("html/${each.value}")
  content_type = lookup(local.content_types, regex("\\.[^.]+$", each.value), null)
}
