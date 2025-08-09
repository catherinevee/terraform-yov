# =============================================================================
# COMPREHENSIVE SECURITY SCAN SCRIPT
# =============================================================================
# Enhanced security scanning for Terragrunt infrastructure
param(
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$Region,
    
    [string]$ConfigPath = ".",
    [switch]$FailOnHigh = $false
)

Write-Host "🔒 Starting comprehensive security scan..." -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host "Path: $ConfigPath" -ForegroundColor Cyan

$ErrorCount = 0
$HighSeverityCount = 0
$startTime = Get-Date

# Security scan checklist
Write-Host "`n📋 Security Validation Checklist:" -ForegroundColor Blue

# 1. Check for hardcoded secrets
Write-Host "🔍 Checking for hardcoded secrets..." -ForegroundColor Blue
$secretPatterns = @(
    "password\s*=\s*[`"'][^`"']+[`"']",
    "secret\s*=\s*[`"'][^`"']+[`"']",
    "aws_access_key_id\s*=\s*[`"'][^`"']+[`"']",
    "aws_secret_access_key\s*=\s*[`"'][^`"']+[`"']"
)

foreach ($pattern in $secretPatterns) {
    $matches = Get-ChildItem -Path $ConfigPath -Recurse -Include "*.hcl", "*.tf" | 
               Select-String -Pattern $pattern -AllMatches
    if ($matches) {
        $ErrorCount++
        $HighSeverityCount++
        Write-Host "🚨 CRITICAL: Potential hardcoded secrets found!" -ForegroundColor Red
        foreach ($match in $matches) {
            Write-Host "   $($match.Filename):$($match.LineNumber)" -ForegroundColor Red
        }
    }
}

# 2. Check for public access configurations
Write-Host "`n🔍 Checking for public access configurations..." -ForegroundColor Blue
$publicAccessPatterns = @(
    'cidr_blocks\s*=\s*\[\s*"0\.0\.0\.0/0"\s*\]',
    'publicly_accessible\s*=\s*true'
)

foreach ($pattern in $publicAccessPatterns) {
    $matches = Get-ChildItem -Path $ConfigPath -Recurse -Include "*.hcl", "*.tf" | 
               Select-String -Pattern $pattern -AllMatches
    if ($matches) {
        $ErrorCount++
        Write-Host "⚠️  WARNING: Public access configuration found!" -ForegroundColor Yellow
        foreach ($match in $matches) {
            Write-Host "   $($match.Filename):$($match.LineNumber)" -ForegroundColor Yellow
        }
    }
}

# 3. Check for missing encryption
Write-Host "`n🔍 Checking for encryption configurations..." -ForegroundColor Blue
$encryptionChecks = Get-ChildItem -Path $ConfigPath -Recurse -Include "*.hcl", "*.tf" | 
                   Select-String -Pattern "encrypt\s*=\s*true" -AllMatches
if (-not $encryptionChecks) {
    $ErrorCount++
    Write-Host "⚠️  WARNING: No encryption configurations found!" -ForegroundColor Yellow
}

# 4. Validate Terragrunt configuration
Write-Host "`n🔍 Validating Terragrunt configuration..." -ForegroundColor Blue
if (Test-Path "$ConfigPath/terragrunt.hcl") {
    try {
        $terragruntValidation = & terragrunt validate --terragrunt-working-dir $ConfigPath 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Terragrunt validation passed" -ForegroundColor Green
        } else {
            $ErrorCount++
            Write-Host "❌ Terragrunt validation failed" -ForegroundColor Red
            Write-Host $terragruntValidation -ForegroundColor Red
        }
    } catch {
        Write-Host "⚠️  WARNING: Could not run terragrunt validation" -ForegroundColor Yellow
    }
} else {
    Write-Host "ℹ️  No terragrunt.hcl found in current path" -ForegroundColor Cyan
}

# 5. Check for required security tags
Write-Host "`n🔍 Checking for security compliance tags..." -ForegroundColor Blue
$requiredTags = @("Environment", "ManagedBy", "security:compliance")
$tagChecks = 0
foreach ($tag in $requiredTags) {
    $tagFound = Get-ChildItem -Path $ConfigPath -Recurse -Include "*.hcl", "*.tf" | 
               Select-String -Pattern $tag -AllMatches
    if ($tagFound) {
        $tagChecks++
    }
}
if ($tagChecks -lt $requiredTags.Count) {
    $ErrorCount++
    Write-Host "⚠️  WARNING: Missing required security tags" -ForegroundColor Yellow
}

# Generate Security Report
$endTime = Get-Date
$duration = $endTime - $startTime
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$reportPath = "security-scan-report-$Environment-$Region-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

$securityReport = @{
    timestamp = $timestamp
    environment = $Environment
    region = $Region
    scan_duration_seconds = $duration.TotalSeconds
    total_errors = $ErrorCount
    high_severity_count = $HighSeverityCount
    scan_status = if ($ErrorCount -eq 0) { "PASS" } else { "FAIL" }
    recommendations = @()
    checks_performed = @(
        "hardcoded_secrets",
        "public_access_configs", 
        "encryption_settings",
        "terragrunt_validation",
        "security_tags"
    )
}

if ($HighSeverityCount -gt 0) {
    $securityReport.recommendations += "🚨 CRITICAL: $HighSeverityCount high-severity security issues require immediate attention"
}
if ($ErrorCount -gt $HighSeverityCount) {
    $securityReport.recommendations += "⚠️  WARNING: $(($ErrorCount - $HighSeverityCount)) medium-severity issues found"
}
if ($ErrorCount -eq 0) {
    $securityReport.recommendations += "✅ Security scan passed - no issues detected"
}

$securityReport | ConvertTo-Json -Depth 3 | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "`n📊 Security Scan Summary:" -ForegroundColor Yellow
Write-Host "   Duration: $([math]::Round($duration.TotalSeconds, 2)) seconds" -ForegroundColor Cyan
Write-Host "   Total Issues: $ErrorCount" -ForegroundColor $(if ($ErrorCount -eq 0) { "Green" } else { "Red" })
Write-Host "   High Severity: $HighSeverityCount" -ForegroundColor $(if ($HighSeverityCount -eq 0) { "Green" } else { "Red" })
Write-Host "   Report: $reportPath" -ForegroundColor Cyan

# Exit with appropriate code
if ($FailOnHigh -and $HighSeverityCount -gt 0) {
    Write-Host "`n❌ Security scan failed due to high-severity issues" -ForegroundColor Red
    exit 1
} elseif ($ErrorCount -gt 0) {
    Write-Host "`n⚠️  Security scan completed with warnings" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "`n✅ Security scan passed successfully" -ForegroundColor Green
    exit 0
}
