#!/bin/bash

# =============================================================================
# INFRASTRUCTURE TOOLS INSTALLATION SCRIPT
# =============================================================================
# Installs required tools for YOV Enterprise Infrastructure development
# Supports Linux, macOS, and Windows (via WSL/Git Bash)

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[0;37m'
readonly NC='\033[0m' # No Color

# Tool versions
readonly TERRAFORM_VERSION="1.5.7"
readonly TERRAGRUNT_VERSION="0.53.0"
readonly TFSEC_VERSION="1.28.1"
readonly CHECKOV_VERSION="3.1.9"
readonly INFRACOST_VERSION="0.10.29"
readonly OPA_VERSION="0.58.0"
readonly TERRAFORM_DOCS_VERSION="0.16.0"

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "darwin"
    elif [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# Detect architecture
detect_arch() {
    case $(uname -m) in
        x86_64) echo "amd64" ;;
        arm64|aarch64) echo "arm64" ;;
        *) echo "amd64" ;;
    esac
}

# Print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Download and install binary
install_binary() {
    local name=$1
    local version=$2
    local url=$3
    local target_path=$4
    local extract_path=${5:-""}
    
    print_message "$CYAN" "Installing ${name} ${version}..."
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # Download
    print_message "$WHITE" "  Downloading from ${url}"
    curl -fsSL "$url" -o "${name}.zip"
    
    # Extract
    if [[ "$url" == *.zip ]]; then
        unzip -q "${name}.zip"
    elif [[ "$url" == *.tar.gz ]]; then
        tar -xzf "${name}.zip"
    fi
    
    # Move to target path
    if [[ -n "$extract_path" ]]; then
        chmod +x "$extract_path"
        sudo mv "$extract_path" "$target_path"
    else
        chmod +x "$name"
        sudo mv "$name" "$target_path"
    fi
    
    # Cleanup
    cd - >/dev/null
    rm -rf "$temp_dir"
    
    print_message "$GREEN" "  ✓ ${name} installed successfully"
}

# Install Terraform
install_terraform() {
    if command_exists terraform; then
        local current_version=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || echo "unknown")
        if [[ "$current_version" == "$TERRAFORM_VERSION" ]]; then
            print_message "$GREEN" "✓ Terraform ${TERRAFORM_VERSION} already installed"
            return
        fi
    fi
    
    local os=$(detect_os)
    local arch=$(detect_arch)
    local url="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${os}_${arch}.zip"
    
    install_binary "terraform" "$TERRAFORM_VERSION" "$url" "/usr/local/bin/terraform" "terraform"
}

# Install Terragrunt
install_terragrunt() {
    if command_exists terragrunt; then
        local current_version=$(terragrunt --version 2>/dev/null | head -n1 | awk '{print $3}' | sed 's/v//' || echo "unknown")
        if [[ "$current_version" == "$TERRAGRUNT_VERSION" ]]; then
            print_message "$GREEN" "✓ Terragrunt ${TERRAGRUNT_VERSION} already installed"
            return
        fi
    fi
    
    local os=$(detect_os)
    local arch=$(detect_arch)
    local url="https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_${os}_${arch}"
    
    print_message "$CYAN" "Installing Terragrunt ${TERRAGRUNT_VERSION}..."
    curl -fsSL "$url" -o terragrunt
    chmod +x terragrunt
    sudo mv terragrunt /usr/local/bin/terragrunt
    print_message "$GREEN" "  ✓ Terragrunt installed successfully"
}

# Install TFSec
install_tfsec() {
    if command_exists tfsec; then
        local current_version=$(tfsec --version 2>/dev/null | awk '{print $2}' || echo "unknown")
        if [[ "$current_version" == "$TFSEC_VERSION" ]]; then
            print_message "$GREEN" "✓ TFSec ${TFSEC_VERSION} already installed"
            return
        fi
    fi
    
    local os=$(detect_os)
    local arch=$(detect_arch)
    local url="https://github.com/aquasecurity/tfsec/releases/download/v${TFSEC_VERSION}/tfsec-${os}-${arch}"
    
    print_message "$CYAN" "Installing TFSec ${TFSEC_VERSION}..."
    curl -fsSL "$url" -o tfsec
    chmod +x tfsec
    sudo mv tfsec /usr/local/bin/tfsec
    print_message "$GREEN" "  ✓ TFSec installed successfully"
}

# Install Checkov
install_checkov() {
    if command_exists checkov; then
        local current_version=$(checkov --version 2>/dev/null | awk '{print $2}' || echo "unknown")
        if [[ "$current_version" == "$CHECKOV_VERSION" ]]; then
            print_message "$GREEN" "✓ Checkov ${CHECKOV_VERSION} already installed"
            return
        fi
    fi
    
    print_message "$CYAN" "Installing Checkov ${CHECKOV_VERSION}..."
    pip3 install checkov==$CHECKOV_VERSION
    print_message "$GREEN" "  ✓ Checkov installed successfully"
}

# Install Infracost
install_infracost() {
    if command_exists infracost; then
        local current_version=$(infracost --version 2>/dev/null | grep "Infracost" | awk '{print $2}' | sed 's/v//' || echo "unknown")
        if [[ "$current_version" == "$INFRACOST_VERSION" ]]; then
            print_message "$GREEN" "✓ Infracost ${INFRACOST_VERSION} already installed"
            return
        fi
    fi
    
    local os=$(detect_os)
    local arch=$(detect_arch)
    local url="https://github.com/infracost/infracost/releases/download/v${INFRACOST_VERSION}/infracost-${os}-${arch}.tar.gz"
    
    print_message "$CYAN" "Installing Infracost ${INFRACOST_VERSION}..."
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    curl -fsSL "$url" -o infracost.tar.gz
    tar -xzf infracost.tar.gz
    chmod +x infracost-${os}-${arch}
    sudo mv infracost-${os}-${arch} /usr/local/bin/infracost
    cd - >/dev/null
    rm -rf "$temp_dir"
    print_message "$GREEN" "  ✓ Infracost installed successfully"
}

# Install OPA
install_opa() {
    if command_exists opa; then
        local current_version=$(opa version 2>/dev/null | grep "Version:" | awk '{print $2}' || echo "unknown")
        if [[ "$current_version" == "$OPA_VERSION" ]]; then
            print_message "$GREEN" "✓ OPA ${OPA_VERSION} already installed"
            return
        fi
    fi
    
    local os=$(detect_os)
    local arch=$(detect_arch)
    local url="https://github.com/open-policy-agent/opa/releases/download/v${OPA_VERSION}/opa_${os}_${arch}"
    
    print_message "$CYAN" "Installing OPA ${OPA_VERSION}..."
    curl -fsSL "$url" -o opa
    chmod +x opa
    sudo mv opa /usr/local/bin/opa
    print_message "$GREEN" "  ✓ OPA installed successfully"
}

# Install terraform-docs
install_terraform_docs() {
    if command_exists terraform-docs; then
        local current_version=$(terraform-docs --version 2>/dev/null | awk '{print $3}' | sed 's/v//' || echo "unknown")
        if [[ "$current_version" == "$TERRAFORM_DOCS_VERSION" ]]; then
            print_message "$GREEN" "✓ terraform-docs ${TERRAFORM_DOCS_VERSION} already installed"
            return
        fi
    fi
    
    local os=$(detect_os)
    local arch=$(detect_arch)
    local url="https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-${os}-${arch}.tar.gz"
    
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    curl -fsSL "$url" -o terraform-docs.tar.gz
    tar -xzf terraform-docs.tar.gz
    chmod +x terraform-docs
    sudo mv terraform-docs /usr/local/bin/terraform-docs
    cd - >/dev/null
    rm -rf "$temp_dir"
    
    print_message "$GREEN" "  ✓ terraform-docs installed successfully"
}

# Install pre-commit
install_pre_commit() {
    if command_exists pre-commit; then
        print_message "$GREEN" "✓ pre-commit already installed"
        return
    fi
    
    print_message "$CYAN" "Installing pre-commit..."
    if command_exists pip3; then
        pip3 install pre-commit
    elif command_exists pip; then
        pip install pre-commit
    else
        print_message "$RED" "  ✗ pip not found. Please install Python and pip first."
        return 1
    fi
    print_message "$GREEN" "  ✓ pre-commit installed successfully"
}

# Verify installations
verify_installations() {
    print_message "$CYAN" "Verifying installations..."
    
    local tools=(
        "terraform --version"
        "terragrunt --version"
        "tfsec --version"
        "checkov --version"
        "infracost --version"
        "opa version"
        "terraform-docs --version"
        "pre-commit --version"
    )
    
    local failed=0
    for tool_cmd in "${tools[@]}"; do
        local tool_name=$(echo "$tool_cmd" | awk '{print $1}')
        if command_exists "$tool_name"; then
            local version_output=$($tool_cmd 2>/dev/null || echo "unknown")
            print_message "$GREEN" "  ✓ ${tool_name}: $(echo "$version_output" | head -n1)"
        else
            print_message "$RED" "  ✗ ${tool_name}: not found"
            ((failed++))
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        print_message "$GREEN" "All tools installed successfully!"
    else
        print_message "$YELLOW" "Some tools failed to install. Please check the output above."
    fi
}

# Main installation function
main() {
    print_message "$CYAN" "YOV Infrastructure Tools Installation"
    print_message "$CYAN" "===================================="
    print_message "$WHITE" "Installing tools for Terragrunt enterprise infrastructure..."
    echo
    
    # Check prerequisites
    if ! command_exists curl; then
        print_message "$RED" "Error: curl is required but not installed."
        exit 1
    fi
    
    if ! command_exists jq; then
        print_message "$YELLOW" "Warning: jq is recommended for better version checking."
    fi
    
    # Install tools
    install_terraform
    install_terragrunt
    install_tfsec
    install_checkov
    install_infracost
    install_opa
    install_terraform_docs
    install_pre_commit
    
    echo
    verify_installations
    
    echo
    print_message "$GREEN" "🎉 Installation completed!"
    print_message "$WHITE" "You can now use the following commands:"
    print_message "$YELLOW" "  make setup          # Complete project setup"
    print_message "$YELLOW" "  make validate       # Validate configurations"
    print_message "$YELLOW" "  make security-scan  # Run security scans"
    print_message "$YELLOW" "  make plan           # Plan infrastructure"
    print_message "$YELLOW" "  make help           # Show all available commands"
}

# Run main function
main "$@"
