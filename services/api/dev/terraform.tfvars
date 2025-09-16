primary_region        = "ap-southeast-1"
secondary_region      = "ap-southeast-2"
app_version           = "1.0.0"
domain_name           = ""
enable_multi_region   = false
enable_vpc            = false
enable_waf            = false
alert_email           = ""
tenant_isolation_mode = "pool"

api_usage_plans = {
  free = {
    quota_limit  = 100
    quota_period = "DAY"
    rate_limit   = 5
    burst_limit  = 10
  }
  basic = {
    quota_limit  = 1000
    quota_period = "DAY"
    rate_limit   = 20
    burst_limit  = 40
  }
}