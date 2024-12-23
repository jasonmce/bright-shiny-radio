resource "aws_api_gateway_usage_plan" "myusageplan" {
  name        = "myusageplan"
  description = "This is my API Usage Plan for demonstrating Throttling and Quotas"

  api_stages {
    api_id = aws_api_gateway_rest_api.playlist_api.id
    stage  = "prod"
  }

  throttle_settings {
    burst_limit = 100        // Maximum rate limit
    rate_limit  = 1.0       // Steady state requests per second
  }

  quota_settings {
    limit  = 500            // Total requests in a given period
    offset = 0
    period = "DAY"
  }
}

