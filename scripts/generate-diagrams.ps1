# Terragrunt Infrastructure Diagram Generator
# PowerShell automation for generating Terraform infrastructure diagrams using blast-radius
# 
# Features:
# - Multi-environment, multi-region diagram generation
# - Interactive server deployment for real-time exploration
# - Automated prerequisite checking and dependency validation
# - Production-ready error handling and logging
# - Terragrunt-aware configuration parsing
#
# Usage:
#   .\generate-diagrams.ps1 generate dev eu-central-2           # Generate specific environment
#   .\generate-diagrams.ps1 generate-all                       # Generate all environments
#   .\generate-diagrams.ps1 serve dev eu-central-2 8080       # Start interactive server
#   .\generate-diagrams.ps1 generate-index                     # Generate HTML index

param(
    [Parameter(Position=0)]
    [ValidateSet("generate", "generate-all", "serve", "generate-index", "help")]
    [string]$Command = "generate",
    
    [Parameter(Position=1)]
    [string]$Environment = "dev",
    
    [Parameter(Position=2)]
    [string]$Region = "eu-central-2",
    
    [Parameter(Position=3)]
    [int]$Port = 5000
)

# Get script directory and project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$DiagramsDir = Join-Path $ProjectRoot "diagrams"

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to check prerequisites
function Test-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    # Check if terraform is installed
    try {
        $null = Get-Command terraform -ErrorAction Stop
    }
    catch {
        Write-Error "Terraform is not installed or not in PATH"
        Write-Status "Download from: https://www.terraform.io/downloads.html"
        exit 1
    }
    
    # Check if terragrunt is installed
    try {
        $null = Get-Command terragrunt -ErrorAction Stop
    }
    catch {
        Write-Error "Terragrunt is not installed or not in PATH"
        Write-Status "Download from: https://terragrunt.gruntwork.io/docs/getting-started/install/"
        exit 1
    }
    
    # Check if blast-radius is installed
    try {
        $null = Get-Command blast-radius -ErrorAction Stop
    }
    catch {
        Write-Error "blast-radius is not installed"
        Write-Status "Install with: pip install blastradius"
        exit 1
    }
    
    # Check if graphviz is installed
    try {
        $null = Get-Command dot -ErrorAction Stop
    }
    catch {
        Write-Error "Graphviz is not installed"
        Write-Status "Install with: choco install graphviz"
        Write-Status "Or download from: https://graphviz.org/download/"
        exit 1
    }
    
    Write-Success "All prerequisites are met"
}

# Function to discover available environments
function Get-AvailableEnvironments {
    $environments = @()
    
    # Find all aws/region/environment combinations
    $awsPath = Join-Path $ProjectRoot "aws"
    if (Test-Path $awsPath) {
        Get-ChildItem $awsPath -Directory | ForEach-Object {
            $region = $_.Name
            $regionPath = $_.FullName
            
            Get-ChildItem $regionPath -Directory | ForEach-Object {
                $env = $_.Name
                $envPath = $_.FullName
                
                # Check if this looks like a valid environment (has terragrunt.hcl or terraform files)
                if ((Get-ChildItem $envPath -Filter "*.hcl" -Recurse | Measure-Object).Count -gt 0 -or
                    (Get-ChildItem $envPath -Filter "*.tf" -Recurse | Measure-Object).Count -gt 0) {
                    
                    $environments += @{
                        Region = $region
                        Environment = $env
                        Path = "aws/$region/$env"
                        FullPath = $envPath
                        Name = "$env-$region"
                    }
                }
            }
        }
    }
    
    return $environments
}

# Function to generate diagram for a specific environment
function New-TerragruntDiagram {
    param(
        [string]$EnvPath,
        [string]$EnvName,
        [string]$Region,
        [string]$Environment
    )
    
    Write-Status "Generating diagram for $EnvName..."
    
    $FullEnvPath = Join-Path $ProjectRoot $EnvPath
    
    # Check if environment directory exists
    if (-not (Test-Path $FullEnvPath)) {
        Write-Warning "Environment directory not found: $EnvPath"
        return $false
    }
    
    # Create diagrams directory
    if (-not (Test-Path $DiagramsDir)) {
        New-Item -ItemType Directory -Path $DiagramsDir -Force | Out-Null
    }
    
    # Navigate to environment directory
    Push-Location $FullEnvPath
    
    try {
        # Look for terragrunt or terraform files
        $hasTerragrunt = Test-Path "terragrunt.hcl"
        $hasTerraform = (Get-ChildItem -Filter "*.tf" | Measure-Object).Count -gt 0
        
        if (-not $hassTerragrunt -and -not $hasTerraform) {
            Write-Warning "No Terragrunt or Terraform files found in $EnvPath, skipping..."
            return $false
        }
        
        # Set environment variables for Terragrunt
        $env:AWS_REGION = $Region
        $env:ENVIRONMENT = $Environment
        
        if ($hassTerragrunt) {
            Write-Status "Initializing Terragrunt for $EnvName..."
            & terragrunt init --terragrunt-non-interactive
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Terragrunt init failed for $EnvName, trying terraform init..."
                & terraform init -backend=false
            }
            
            Write-Status "Creating Terragrunt plan for $EnvName..."
            & terragrunt plan -out=tfplan --terragrunt-non-interactive 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Terragrunt plan failed for $EnvName, continuing with existing state..."
            }
        }
        else {
            Write-Status "Initializing Terraform for $EnvName..."
            & terraform init -backend=false
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Terraform init failed for $EnvName"
                return $false
            }
            
            Write-Status "Creating Terraform plan for $EnvName..."
            & terraform plan -out=tfplan 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Terraform plan failed for $EnvName, continuing with existing state..."
            }
        }
        
        # Generate SVG diagram
        $OutputFile = Join-Path $DiagramsDir "$EnvName.svg"
        Write-Status "Generating SVG diagram: $OutputFile"
        
        & blast-radius --svg > $OutputFile 2>$null
        if ($LASTEXITCODE -eq 0 -and (Test-Path $OutputFile)) {
            Write-Success "Generated diagram: diagrams\$EnvName.svg"
            $success = $true
        }
        else {
            Write-Error "Failed to generate diagram for $EnvName"
            # Create placeholder SVG
            $placeholderSvg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="400" height="200" viewBox="0 0 400 200">
    <rect width="400" height="200" fill="#f8f9fa" stroke="#dee2e6" stroke-width="1"/>
    <text x="200" y="100" text-anchor="middle" font-family="Arial, sans-serif" font-size="14" fill="#6c757d">
        Diagram generation failed for $EnvName
    </text>
    <text x="200" y="120" text-anchor="middle" font-family="Arial, sans-serif" font-size="12" fill="#6c757d">
        Check logs for details
    </text>
</svg>
"@
            Set-Content -Path $OutputFile -Value $placeholderSvg
            $success = $false
        }
        
        # Generate DOT file for debugging
        $DotFile = Join-Path $DiagramsDir "$EnvName.dot"
        & blast-radius --dot > $DotFile 2>$null
        
        # Clean up plan file
        if (Test-Path "tfplan") {
            Remove-Item "tfplan" -Force
        }
        
        return $success
    }
    finally {
        # Return to original directory
        Pop-Location
    }
}

# Function to generate diagrams for all environments
function New-AllTerragruntDiagrams {
    Write-Status "Discovering available environments..."
    
    $environments = Get-AvailableEnvironments
    
    if ($environments.Count -eq 0) {
        Write-Warning "No environments found in aws/ directory"
        return
    }
    
    Write-Status "Found $($environments.Count) environments:"
    $environments | ForEach-Object { Write-Host "  - $($_.Name) ($($_.Path))" -ForegroundColor Gray }
    
    $successCount = 0
    $totalCount = $environments.Count
    
    # Generate diagrams for each environment
    foreach ($env in $environments) {
        if (New-TerragruntDiagram -EnvPath $env.Path -EnvName $env.Name -Region $env.Region -Environment $env.Environment) {
            $successCount++
        }
    }
    
    Write-Status "Diagram generation completed: $successCount/$totalCount successful"
    
    if ($successCount -gt 0) {
        New-DiagramIndex
    }
}

# Function to start interactive server for specific environment
function Start-BlastRadiusServer {
    param(
        [string]$Environment,
        [string]$Region,
        [int]$Port = 5000
    )
    
    $EnvPath = "aws/$Region/$Environment"
    Write-Status "Starting blast-radius server for $Environment in $Region..."
    
    $FullEnvPath = Join-Path $ProjectRoot $EnvPath
    
    # Check if environment directory exists
    if (-not (Test-Path $FullEnvPath)) {
        Write-Error "Environment directory not found: $EnvPath"
        Write-Status "Available environments:"
        $environments = Get-AvailableEnvironments
        $environments | ForEach-Object { Write-Host "  - $($_.Environment) in $($_.Region)" -ForegroundColor Gray }
        exit 1
    }
    
    # Navigate to environment directory
    Push-Location $FullEnvPath
    
    try {
        # Set environment variables
        $env:AWS_REGION = $Region
        $env:ENVIRONMENT = $Environment
        
        # Check if terragrunt or terraform files exist
        $hassTerragrunt = Test-Path "terragrunt.hcl"
        $hasTerraform = (Get-ChildItem -Filter "*.tf" | Measure-Object).Count -gt 0
        
        if (-not $hassTerragrunt -and -not $hasTerraform) {
            Write-Error "No Terragrunt or Terraform files found in $EnvPath"
            exit 1
        }
        
        # Initialize and plan
        if ($hassTerragrunt) {
            Write-Status "Initializing Terragrunt..."
            & terragrunt init --terragrunt-non-interactive
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Terragrunt init failed"
                exit 1
            }
            
            Write-Status "Creating Terragrunt plan..."
            & terragrunt plan -out=tfplan --terragrunt-non-interactive
        }
        else {
            Write-Status "Initializing Terraform..."
            & terraform init -backend=false
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Terraform init failed"
                exit 1
            }
            
            Write-Status "Creating Terraform plan..."
            & terraform plan -out=tfplan
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Plan creation failed"
            exit 1
        }
        
        Write-Success "Starting server on http://localhost:$Port"
        Write-Status "Press Ctrl+C to stop the server"
        
        # Start blast-radius server
        & blast-radius --serve --port $Port
    }
    finally {
        # Clean up plan file
        if (Test-Path "tfplan") {
            Remove-Item "tfplan" -Force
        }
        
        # Return to original directory
        Pop-Location
    }
}

# Function to generate HTML index of all diagrams
function New-DiagramIndex {
    Write-Status "Generating diagram index..."
    
    $IndexFile = Join-Path $DiagramsDir "index.html"
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>YOV Infrastructure Diagrams</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background-color: #f8f9fa; 
            line-height: 1.6;
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            background: white; 
            padding: 30px; 
            border-radius: 10px; 
            box-shadow: 0 4px 20px rgba(0,0,0,0.1); 
        }
        h1 { 
            color: #2c3e50; 
            text-align: center; 
            margin-bottom: 10px;
            font-size: 2.5em;
        }
        .subtitle {
            text-align: center;
            color: #7f8c8d;
            font-size: 1.1em;
            margin-bottom: 30px;
        }
        .diagram-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); 
            gap: 25px; 
            margin: 30px 0; 
        }
        .diagram-card { 
            border: 1px solid #e1e8ed; 
            border-radius: 10px; 
            padding: 20px; 
            background: #fafbfc; 
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .diagram-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 25px rgba(0,0,0,0.15);
        }
        .diagram-card h3 { 
            margin-top: 0; 
            margin-bottom: 15px;
            color: #2c3e50; 
            font-size: 1.3em;
        }
        .diagram-preview { 
            text-align: center; 
            margin: 15px 0; 
        }
        .diagram-preview img { 
            max-width: 100%; 
            height: auto; 
            border: 1px solid #d1d9e0; 
            border-radius: 5px;
            transition: transform 0.2s;
        }
        .diagram-preview img:hover {
            transform: scale(1.02);
        }
        .view-link {
            display: inline-block;
            padding: 8px 16px;
            background: #3498db;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            transition: background 0.2s;
        }
        .view-link:hover {
            background: #2980b9;
        }
        .timestamp { 
            color: #95a5a6; 
            font-size: 0.9em; 
            text-align: center; 
            margin-top: 30px; 
            padding-top: 20px;
            border-top: 1px solid #ecf0f1;
        }
        .env-dev { border-left: 5px solid #3498db; }
        .env-staging { border-left: 5px solid #f39c12; }
        .env-prod { border-left: 5px solid #e74c3c; }
        .stats {
            background: #ecf0f1;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>YOV Infrastructure Diagrams</h1>
        <div class="subtitle">Interactive visualizations of our enterprise Terragrunt infrastructure</div>
        
"@
    
    # Get all SVG files
    $svgFiles = Get-ChildItem $DiagramsDir -Filter "*.svg" | Sort-Object Name
    
    if ($svgFiles.Count -gt 0) {
        $html += "<div class='stats'>Total Environments: $($svgFiles.Count)</div>`r`n"
        $html += "<div class='diagram-grid'>`r`n"
        
        foreach ($svg in $svgFiles) {
            $filename = $svg.Name
            $name = $svg.BaseName
            
            # Determine environment class
            $envClass = ""
            if ($name -like "*dev*") { $envClass = "env-dev" }
            elseif ($name -like "*staging*") { $envClass = "env-staging" }
            elseif ($name -like "*prod*") { $envClass = "env-prod" }
            
            # Extract environment and region from name
            $parts = $name -split "-"
            $environment = $parts[0]
            $region = $parts[1..($parts.Length-1)] -join "-"
            
            $html += @"
            <div class="diagram-card $envClass">
                <h3>$environment ($region)</h3>
                <div class="diagram-preview">
                    <a href="$filename" target="_blank">
                        <img src="$filename" alt="$name infrastructure diagram" loading="lazy">
                    </a>
                </div>
                <p style="text-align: center;">
                    <a href="$filename" target="_blank" class="view-link">View Full Diagram</a>
                </p>
            </div>

"@
        }
        
        $html += "</div>`r`n"
    }
    else {
        $html += "<div class='stats'>No diagrams found. Run 'make diagrams' to generate them.</div>`r`n"
    }
    
    $html += @"
        <div class="timestamp">
            Last updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')
        </div>
    </div>
</body>
</html>
"@
    
    Set-Content -Path $IndexFile -Value $html -Encoding UTF8
    Write-Success "Generated diagram index: diagrams\index.html"
}

# Function to show help
function Show-Help {
    $HelpText = @"
Terragrunt Infrastructure Diagram Generator

USAGE:
    .\generate-diagrams.ps1 [COMMAND] [OPTIONS]

COMMANDS:
    generate [ENV] [REGION]     Generate diagram for specific environment
    generate-all                Generate diagrams for all discovered environments  
    serve [ENV] [REGION] [PORT] Start interactive server for environment
    generate-index              Generate HTML index of all diagrams
    help                        Show this help message

EXAMPLES:
    .\generate-diagrams.ps1 generate dev eu-central-2          # Generate diagram for dev in eu-central-2
    .\generate-diagrams.ps1 generate-all                       # Generate diagrams for all environments
    .\generate-diagrams.ps1 serve prod eu-central-2            # Start server for prod environment
    .\generate-diagrams.ps1 serve dev eu-central-2 8080       # Start server on custom port
    .\generate-diagrams.ps1 generate-index                     # Generate HTML index

PREREQUISITES:
    - Terraform (https://www.terraform.io/downloads.html)
    - Terragrunt (https://terragrunt.gruntwork.io/docs/getting-started/install/)
    - Python with pip
    - blast-radius (pip install blastradius)
    - Graphviz (choco install graphviz)

ENVIRONMENT DISCOVERY:
    The script automatically discovers environments in the aws/ directory structure:
    aws/[region]/[environment]/
    
    Supported regions: eu-central-2, eu-west-1, us-east-1, etc.
    Supported environments: dev, staging, prod, etc.

"@
    Write-Host $HelpText
}

# Main execution
switch ($Command) {
    "generate" {
        Test-Prerequisites
        $EnvPath = "aws/$Region/$Environment"
        $EnvName = "$Environment-$Region"
        $success = New-TerragruntDiagram -EnvPath $EnvPath -EnvName $EnvName -Region $Region -Environment $Environment
        if ($success) {
            New-DiagramIndex
        }
    }
    "generate-all" {
        Test-Prerequisites
        New-AllTerragruntDiagrams
    }
    "serve" {
        Test-Prerequisites
        Start-BlastRadiusServer -Environment $Environment -Region $Region -Port $Port
    }
    "generate-index" {
        New-DiagramIndex
    }
    "help" {
        Show-Help
    }
    default {
        Write-Error "Unknown command: $Command"
        Show-Help
        exit 1
    }
}
