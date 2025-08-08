#!/bin/bash

# Terragrunt Infrastructure Diagram Generator
# Cross-platform bash automation for generating Terraform infrastructure diagrams using blast-radius
# 
# Features:
# - Multi-environment, multi-region diagram generation
# - Interactive server deployment for real-time exploration
# - Automated prerequisite checking and dependency validation
# - Production-ready error handling and logging
# - Terragrunt-aware configuration parsing
#
# Usage:
#   ./generate-diagrams.sh generate dev eu-central-2           # Generate specific environment
#   ./generate-diagrams.sh generate-all                        # Generate all environments
#   ./generate-diagrams.sh serve dev eu-central-2 8080        # Start interactive server
#   ./generate-diagrams.sh generate-index                      # Generate HTML index

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DIAGRAMS_DIR="$PROJECT_ROOT/diagrams"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed or not in PATH"
        print_status "Download from: https://www.terraform.io/downloads.html"
        exit 1
    fi
    
    # Check if terragrunt is installed
    if ! command -v terragrunt &> /dev/null; then
        print_error "Terragrunt is not installed or not in PATH"
        print_status "Download from: https://terragrunt.gruntwork.io/docs/getting-started/install/"
        exit 1
    fi
    
    # Check if blast-radius is installed
    if ! command -v blast-radius &> /dev/null; then
        print_error "blast-radius is not installed"
        print_status "Install with: pip install blastradius"
        exit 1
    fi
    
    # Check if graphviz is installed
    if ! command -v dot &> /dev/null; then
        print_error "Graphviz is not installed"
        print_status "Install graphviz before proceeding"
        case "$(uname -s)" in
            Darwin*)
                print_status "macOS: brew install graphviz"
                ;;
            Linux*)
                print_status "Linux: sudo apt-get install graphviz"
                ;;
            *)
                print_status "Other: Check https://graphviz.org/download/"
                ;;
        esac
        exit 1
    fi
    
    print_success "All prerequisites are met"
}

# Function to discover available environments
discover_environments() {
    local environments=()
    
    # Find all aws/region/environment combinations
    for region_dir in "$PROJECT_ROOT/aws"/*/; do
        if [ -d "$region_dir" ]; then
            local region=$(basename "$region_dir")
            
            for env_dir in "$region_dir"*/; do
                if [ -d "$env_dir" ]; then
                    local environment=$(basename "$env_dir")
                    local env_path="aws/$region/$environment"
                    
                    # Check if this looks like a valid environment
                    if find "$env_dir" -name "*.hcl" -o -name "*.tf" | grep -q .; then
                        local env_name="$environment-$region"
                        environments+=("$env_path:$env_name:$region:$environment")
                    fi
                fi
            done
        fi
    done
    
    printf '%s\n' "${environments[@]}"
}

# Function to generate diagram for a specific environment
generate_terragrunt_diagram() {
    local env_path="$1"
    local env_name="$2"
    local region="$3"
    local environment="$4"
    
    print_status "Generating diagram for $env_name..."
    
    local full_env_path="$PROJECT_ROOT/$env_path"
    
    # Check if environment directory exists
    if [ ! -d "$full_env_path" ]; then
        print_warning "Environment directory not found: $env_path"
        return 1
    fi
    
    # Create diagrams directory
    mkdir -p "$DIAGRAMS_DIR"
    
    # Navigate to environment directory
    cd "$full_env_path"
    
    # Look for terragrunt or terraform files
    local has_terragrunt=false
    local has_terraform=false
    
    if [ -f "terragrunt.hcl" ]; then
        has_terragrunt=true
    fi
    
    if find . -maxdepth 1 -name "*.tf" | grep -q .; then
        has_terraform=true
    fi
    
    if [ "$has_terragrunt" = false ] && [ "$has_terraform" = false ]; then
        print_warning "No Terragrunt or Terraform files found in $env_path, skipping..."
        cd "$PROJECT_ROOT"
        return 1
    fi
    
    # Set environment variables for Terragrunt
    export AWS_REGION="$region"
    export ENVIRONMENT="$environment"
    
    if [ "$has_terragrunt" = true ]; then
        print_status "Initializing Terragrunt for $env_name..."
        if ! terragrunt init --terragrunt-non-interactive; then
            print_warning "Terragrunt init failed for $env_name, trying terraform init..."
            terraform init -backend=false || true
        fi
        
        print_status "Creating Terragrunt plan for $env_name..."
        terragrunt plan -out=tfplan --terragrunt-non-interactive 2>/dev/null || {
            print_warning "Terragrunt plan failed for $env_name, continuing with existing state..."
        }
    else
        print_status "Initializing Terraform for $env_name..."
        if ! terraform init -backend=false; then
            print_error "Terraform init failed for $env_name"
            cd "$PROJECT_ROOT"
            return 1
        fi
        
        print_status "Creating Terraform plan for $env_name..."
        terraform plan -out=tfplan 2>/dev/null || {
            print_warning "Terraform plan failed for $env_name, continuing with existing state..."
        }
    fi
    
    # Generate SVG diagram
    local output_file="$DIAGRAMS_DIR/$env_name.svg"
    print_status "Generating SVG diagram: $output_file"
    
    if blast-radius --svg > "$output_file" 2>/dev/null && [ -s "$output_file" ]; then
        print_success "Generated diagram: diagrams/$env_name.svg"
        local success=true
    else
        print_error "Failed to generate diagram for $env_name"
        # Create placeholder SVG
        cat > "$output_file" << EOF
<svg xmlns="http://www.w3.org/2000/svg" width="400" height="200" viewBox="0 0 400 200">
    <rect width="400" height="200" fill="#f8f9fa" stroke="#dee2e6" stroke-width="1"/>
    <text x="200" y="100" text-anchor="middle" font-family="Arial, sans-serif" font-size="14" fill="#6c757d">
        Diagram generation failed for $env_name
    </text>
    <text x="200" y="120" text-anchor="middle" font-family="Arial, sans-serif" font-size="12" fill="#6c757d">
        Check logs for details
    </text>
</svg>
EOF
        local success=false
    fi
    
    # Generate DOT file for debugging
    local dot_file="$DIAGRAMS_DIR/$env_name.dot"
    blast-radius --dot > "$dot_file" 2>/dev/null || true
    
    # Clean up plan file
    rm -f tfplan
    
    # Return to project root
    cd "$PROJECT_ROOT"
    
    [ "$success" = true ]
}

# Function to generate diagrams for all environments
generate_all_terragrunt_diagrams() {
    print_status "Discovering available environments..."
    
    local environments
    mapfile -t environments < <(discover_environments)
    
    if [ ${#environments[@]} -eq 0 ]; then
        print_warning "No environments found in aws/ directory"
        return
    fi
    
    print_status "Found ${#environments[@]} environments:"
    for env_info in "${environments[@]}"; do
        IFS=':' read -r env_path env_name region environment <<< "$env_info"
        echo "  - $env_name ($env_path)"
    done
    
    local success_count=0
    local total_count=${#environments[@]}
    
    # Generate diagrams for each environment
    for env_info in "${environments[@]}"; do
        IFS=':' read -r env_path env_name region environment <<< "$env_info"
        if generate_terragrunt_diagram "$env_path" "$env_name" "$region" "$environment"; then
            ((success_count++))
        fi
    done
    
    print_status "Diagram generation completed: $success_count/$total_count successful"
    
    if [ $success_count -gt 0 ]; then
        generate_diagram_index
    fi
}

# Function to start interactive server for specific environment
start_blast_radius_server() {
    local environment="$1"
    local region="$2"
    local port="${3:-5000}"
    
    local env_path="aws/$region/$environment"
    print_status "Starting blast-radius server for $environment in $region..."
    
    local full_env_path="$PROJECT_ROOT/$env_path"
    
    # Check if environment directory exists
    if [ ! -d "$full_env_path" ]; then
        print_error "Environment directory not found: $env_path"
        print_status "Available environments:"
        local environments
        mapfile -t environments < <(discover_environments)
        for env_info in "${environments[@]}"; do
            IFS=':' read -r _ env_name _ _ <<< "$env_info"
            echo "  - $env_name"
        done
        exit 1
    fi
    
    # Navigate to environment directory
    cd "$full_env_path"
    
    # Set environment variables
    export AWS_REGION="$region"
    export ENVIRONMENT="$environment"
    
    # Check if terragrunt or terraform files exist
    local has_terragrunt=false
    local has_terraform=false
    
    if [ -f "terragrunt.hcl" ]; then
        has_terragrunt=true
    fi
    
    if find . -maxdepth 1 -name "*.tf" | grep -q .; then
        has_terraform=true
    fi
    
    if [ "$has_terragrunt" = false ] && [ "$has_terraform" = false ]; then
        print_error "No Terragrunt or Terraform files found in $env_path"
        exit 1
    fi
    
    # Initialize and plan
    if [ "$has_terragrunt" = true ]; then
        print_status "Initializing Terragrunt..."
        if ! terragrunt init --terragrunt-non-interactive; then
            print_error "Terragrunt init failed"
            exit 1
        fi
        
        print_status "Creating Terragrunt plan..."
        if ! terragrunt plan -out=tfplan --terragrunt-non-interactive; then
            print_error "Terragrunt plan failed"
            exit 1
        fi
    else
        print_status "Initializing Terraform..."
        if ! terraform init -backend=false; then
            print_error "Terraform init failed"
            exit 1
        fi
        
        print_status "Creating Terraform plan..."
        if ! terraform plan -out=tfplan; then
            print_error "Terraform plan failed"
            exit 1
        fi
    fi
    
    print_success "Starting server on http://localhost:$port"
    print_status "Press Ctrl+C to stop the server"
    
    # Cleanup function for trap
    cleanup() {
        print_status "Cleaning up..."
        rm -f tfplan
        cd "$PROJECT_ROOT"
    }
    trap cleanup EXIT
    
    # Start blast-radius server
    blast-radius --serve --port "$port"
}

# Function to generate HTML index of all diagrams
generate_diagram_index() {
    print_status "Generating diagram index..."
    
    local index_file="$DIAGRAMS_DIR/index.html"
    
    cat > "$index_file" << 'EOF'
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
        
EOF
    
    # Get all SVG files
    local svg_files=("$DIAGRAMS_DIR"/*.svg)
    local svg_count=0
    
    # Count actual SVG files
    for svg in "${svg_files[@]}"; do
        if [ -f "$svg" ]; then
            ((svg_count++))
        fi
    done
    
    if [ $svg_count -gt 0 ]; then
        echo "        <div class='stats'>Total Environments: $svg_count</div>" >> "$index_file"
        echo "        <div class='diagram-grid'>" >> "$index_file"
        
        for svg in "${svg_files[@]}"; do
            if [ -f "$svg" ]; then
                local filename=$(basename "$svg")
                local name="${filename%.svg}"
                
                # Determine environment class
                local env_class=""
                if [[ $name == *"dev"* ]]; then
                    env_class="env-dev"
                elif [[ $name == *"staging"* ]]; then
                    env_class="env-staging"
                elif [[ $name == *"prod"* ]]; then
                    env_class="env-prod"
                fi
                
                # Extract environment and region from name
                IFS='-' read -ra parts <<< "$name"
                local environment="${parts[0]}"
                local region="${parts[*]:1}"
                region="${region// /-}"
                
                cat >> "$index_file" << EOF
            <div class="diagram-card $env_class">
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
EOF
            fi
        done
        
        echo "        </div>" >> "$index_file"
    else
        echo "        <div class='stats'>No diagrams found. Run './generate-diagrams.sh generate-all' to generate them.</div>" >> "$index_file"
    fi
    
    cat >> "$index_file" << EOF
        <div class="timestamp">
            Last updated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
        </div>
    </div>
</body>
</html>
EOF
    
    print_success "Generated diagram index: diagrams/index.html"
}

# Function to show help
show_help() {
    cat << 'EOF'
Terragrunt Infrastructure Diagram Generator

USAGE:
    ./generate-diagrams.sh [COMMAND] [OPTIONS]

COMMANDS:
    generate [ENV] [REGION]     Generate diagram for specific environment
    generate-all                Generate diagrams for all discovered environments  
    serve [ENV] [REGION] [PORT] Start interactive server for environment
    generate-index              Generate HTML index of all diagrams
    help                        Show this help message

EXAMPLES:
    ./generate-diagrams.sh generate dev eu-central-2          # Generate diagram for dev in eu-central-2
    ./generate-diagrams.sh generate-all                       # Generate diagrams for all environments
    ./generate-diagrams.sh serve prod eu-central-2            # Start server for prod environment
    ./generate-diagrams.sh serve dev eu-central-2 8080       # Start server on custom port
    ./generate-diagrams.sh generate-index                     # Generate HTML index

PREREQUISITES:
    - Terraform (https://www.terraform.io/downloads.html)
    - Terragrunt (https://terragrunt.gruntwork.io/docs/getting-started/install/)
    - Python with pip
    - blast-radius (pip install blastradius)
    - Graphviz (platform-specific installation)

ENVIRONMENT DISCOVERY:
    The script automatically discovers environments in the aws/ directory structure:
    aws/[region]/[environment]/
    
    Supported regions: eu-central-2, eu-west-1, us-east-1, etc.
    Supported environments: dev, staging, prod, etc.

EOF
}

# Main execution
case "${1:-generate}" in
    "generate")
        check_prerequisites
        environment="${2:-dev}"
        region="${3:-eu-central-2}"
        env_path="aws/$region/$environment"
        env_name="$environment-$region"
        if generate_terragrunt_diagram "$env_path" "$env_name" "$region" "$environment"; then
            generate_diagram_index
        fi
        ;;
    "generate-all")
        check_prerequisites
        generate_all_terragrunt_diagrams
        ;;
    "serve")
        check_prerequisites
        environment="${2:-dev}"
        region="${3:-eu-central-2}"
        port="${4:-5000}"
        start_blast_radius_server "$environment" "$region" "$port"
        ;;
    "generate-index")
        generate_diagram_index
        ;;
    "help")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
