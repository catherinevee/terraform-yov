primary_region        = "ap-southeast-1"
secondary_region      = "ap-southeast-2"
app_version           = "1.0.0"
domain_name           = "api.example.com"
enable_multi_region   = true
enable_vpc            = true
enable_waf            = true
alert_email           = "platform-team@example.com"
tenant_isolation_mode = "silo"

api_usage_plans = {
  free = {
    quota_limit  = 1000
    quota_period = "DAY"
    rate_limit   = 10
    burst_limit  = 20
  }
  basic = {
    quota_limit  = 10000
    quota_period = "DAY"
    rate_limit   = 50
    burst_limit  = 100
  }
  premium = {
    quota_limit  = 100000
    quota_period = "DAY"
    rate_limit   = 100
    burst_limit  = 200
  }
  enterprise = {
    quota_limit  = 1000000
    quota_period = "DAY"
    rate_limit   = 500
    burst_limit  = 1000
  }
}