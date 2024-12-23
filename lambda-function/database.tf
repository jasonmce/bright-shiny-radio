# DynamoDB Table
resource "aws_dynamodb_table" "playlist" {
  name         = "playlist"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "pk"
  range_key = "timestamp"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}
