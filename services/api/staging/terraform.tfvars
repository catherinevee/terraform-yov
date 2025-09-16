primary_region        = "ap-southeast-1"
secondary_region      = "ap-southeast-2"
app_version           = "1.0.0"
domain_name           = ""
enable_multi_region   = false
enable_vpc            = true
enable_waf            = true
alert_email           = "platform-team@example.com"
tenant_isolation_mode = "pool"

api_usage_plans = {
  free = {
    quota_limit  = 500
    quota_period = "DAY"
    rate_limit   = 10
    burst_limit  = 20
  }
  basic = {
    quota_limit  = 5000
    quota_period = "DAY"
    rate_limit   = 50
    burst_limit  = 100
  }
  premium = {
    quota_limit  = 50000
    quota_period = "DAY"
    rate_limit   = 100
    burst_limit  = 200
  }
}