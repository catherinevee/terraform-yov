# =============================================================================
# TERRAGRUNT ENTERPRISE INFRASTRUCTURE MAKEFILE
# =============================================================================
# Comprehensive automation for Terragrunt infrastructure management
# Supports multi-environment, multi-region, and multi-cloud deployments

# Default values
AWS_REGION ?= eu-central-2
ENVIRONMENT ?= dev
COMPONENT ?= all
ACTION ?= plan

# Tool versions
TERRAFORM_VERSION := 1.9.5
TERRAGRUNT_VERSION := 0.67.16
TFSEC_VERSION := 1.28.10
CHECKOV_VERSION := 3.2.255
INFRACOST_VERSION := 0.10.38
AWS_CLI_VERSION := 2.17.32
AZURE_CLI_VERSION := 2.63.0
GCLOUD_CLI_VERSION := 487.0.0

# Color codes for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
CYAN := \033[0;36m
WHITE := \033[0;37m
NC := \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# =============================================================================
# HELP AND INFORMATION
# =============================================================================

.PHONY: help
help: ## Show this help message
	@echo "$(CYAN)YOV Infrastructure Management$(NC)"
	@echo "$(CYAN)===============================$(NC)"
	@echo ""
	@echo "$(YELLOW)Usage:$(NC)"
	@echo "  make <target> [ENVIRONMENT=<env>] [AWS_REGION=<region>] [COMPONENT=<component>]"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make plan ENVIRONMENT=prod AWS_REGION=eu-central-2"
	@echo "  make apply ENVIRONMENT=staging COMPONENT=networking/vpc"
	@echo "  make diagrams ENVIRONMENT=prod AWS_REGION=eu-central-2"
	@echo "  make diagram-all"
	@echo "  make serve-diagram ENVIRONMENT=dev AWS_REGION=eu-central-2"
	@echo "  make security-scan"
	@echo "  make cost-estimate ENVIRONMENT=prod"
	@echo ""
	@echo "$(YELLOW)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: info
info: ## Show current configuration
	@echo "$(CYAN)Current Configuration:$(NC)"
	@echo "$(WHITE)Environment:$(NC)     $(YELLOW)$(ENVIRONMENT)$(NC)"
	@echo "$(WHITE)AWS Region:$(NC)      $(YELLOW)$(AWS_REGION)$(NC)"
	@echo "$(WHITE)Component:$(NC)       $(YELLOW)$(COMPONENT)$(NC)"
	@echo "$(WHITE)Action:$(NC)          $(YELLOW)$(ACTION)$(NC)"
	@echo ""
	@echo "$(WHITE)Tool Versions:$(NC)"
	@echo "$(WHITE)Terraform:$(NC)       $(YELLOW)$(TERRAFORM_VERSION)$(NC)"
	@echo "$(WHITE)Terragrunt:$(NC)      $(YELLOW)$(TERRAGRUNT_VERSION)$(NC)"

# =============================================================================
# SETUP AND INSTALLATION
# =============================================================================

.PHONY: install-tools
install-tools: ## Install required tools (Terraform, Terragrunt, etc.)
	@echo "$(CYAN)Installing infrastructure tools...$(NC)"
	@./scripts/install-tools.sh

.PHONY: setup
setup: install-tools install-pre-commit ## Complete setup for new developers
	@echo "$(GREEN)Setup completed successfully!$(NC)"

.PHONY: install-pre-commit
install-pre-commit: ## Install pre-commit hooks
	@echo "$(CYAN)Installing pre-commit hooks...$(NC)"
	@command -v pre-commit >/dev/null 2>&1 || pip install pre-commit
	@pre-commit install
	@pre-commit install --hook-type commit-msg
	@echo "$(GREEN)Pre-commit hooks installed$(NC)"

# =============================================================================
# VALIDATION AND FORMATTING
# =============================================================================

.PHONY: validate
validate: ## Validate all Terragrunt configurations
	@echo "$(CYAN)Validating Terragrunt configurations...$(NC)"
	@find . -name "terragrunt.hcl" -type f | while read -r file; do \
		echo "$(WHITE)Validating:$(NC) $$file"; \
		cd "$$(dirname "$$file")"; \
		terragrunt validate-inputs --terragrunt-non-interactive || exit 1; \
		cd - > /dev/null; \
	done
	@echo "$(GREEN)All configurations are valid$(NC)"

.PHONY: format
format: ## Format all HCL files
	@echo "$(CYAN)Formatting HCL files...$(NC)"
	@terragrunt hclfmt --terragrunt-diff
	@echo "$(GREEN)Formatting completed$(NC)"

.PHONY: format-check
format-check: ## Check if files are properly formatted
	@echo "$(CYAN)Checking HCL formatting...$(NC)"
	@terragrunt hclfmt --terragrunt-check --terragrunt-diff

.PHONY: lint
lint: format-check validate ## Run all linting checks
	@echo "$(GREEN)All lint checks passed$(NC)"

# =============================================================================
# SECURITY SCANNING
# =============================================================================

.PHONY: security-scan
security-scan: tfsec-scan checkov-scan ## Run comprehensive security scans
	@echo "$(GREEN)Security scanning completed$(NC)"

.PHONY: tfsec-scan
tfsec-scan: ## Run TFSec security scan
	@echo "$(CYAN)Running TFSec security scan...$(NC)"
	@command -v tfsec >/dev/null 2>&1 || (echo "$(RED)TFSec not installed$(NC)" && exit 1)
	@tfsec . --config-file .tfsec.yml --format table --minimum-severity HIGH

.PHONY: checkov-scan
checkov-scan: ## Run Checkov security scan
	@echo "$(CYAN)Running Checkov security scan...$(NC)"
	@command -v checkov >/dev/null 2>&1 || pip install checkov==$(CHECKOV_VERSION)
	@checkov --directory . --framework terraform --quiet --compact

.PHONY: policy-check
policy-check: ## Run OPA policy validation
	@echo "$(CYAN)Running OPA policy validation...$(NC)"
	@command -v opa >/dev/null 2>&1 || (echo "$(RED)OPA not installed$(NC)" && exit 1)
	@opa test policies/

# =============================================================================
# COST ESTIMATION
# =============================================================================

.PHONY: cost-estimate
cost-estimate: ## Generate infrastructure cost estimates
	@echo "$(CYAN)Generating cost estimates for $(ENVIRONMENT) in $(AWS_REGION)...$(NC)"
	@command -v infracost >/dev/null 2>&1 || (echo "$(RED)Infracost not installed$(NC)" && exit 1)
	@if [ -d "aws/$(AWS_REGION)/$(ENVIRONMENT)" ]; then \
		infracost breakdown \
			--path "aws/$(AWS_REGION)/$(ENVIRONMENT)" \
			--format table \
			--project-name "yov-infrastructure-$(ENVIRONMENT)-$(AWS_REGION)"; \
	else \
		echo "$(RED)Directory aws/$(AWS_REGION)/$(ENVIRONMENT) not found$(NC)"; \
		exit 1; \
	fi

.PHONY: cost-diff
cost-diff: ## Show cost difference for changes
	@echo "$(CYAN)Generating cost diff...$(NC)"
	@infracost diff \
		--path "aws/$(AWS_REGION)/$(ENVIRONMENT)" \
		--format table

# =============================================================================
# TERRAGRUNT OPERATIONS
# =============================================================================

.PHONY: init
init: ## Initialize Terragrunt for specified environment
	@echo "$(CYAN)Initializing $(ENVIRONMENT) in $(AWS_REGION)...$(NC)"
	@$(call run_terragrunt,init)

.PHONY: plan
plan: ## Plan infrastructure changes
	@echo "$(CYAN)Planning $(ENVIRONMENT) in $(AWS_REGION)...$(NC)"
	@$(call run_terragrunt,plan)

.PHONY: apply
apply: ## Apply infrastructure changes
	@echo "$(CYAN)Applying $(ENVIRONMENT) in $(AWS_REGION)...$(NC)"
	@$(call run_terragrunt,apply)

.PHONY: destroy
destroy: ## Destroy infrastructure (USE WITH CAUTION)
	@echo "$(RED)WARNING: This will destroy infrastructure in $(ENVIRONMENT)!$(NC)"
	@echo "$(RED)Environment: $(ENVIRONMENT)$(NC)"
	@echo "$(RED)Region: $(AWS_REGION)$(NC)"
	@echo "$(RED)Component: $(COMPONENT)$(NC)"
	@read -p "Type 'YES' to confirm destruction: " confirm; \
	if [ "$$confirm" = "YES" ]; then \
		echo "$(CYAN)Destroying infrastructure...$(NC)"; \
		$(call run_terragrunt,destroy); \
	else \
		echo "$(YELLOW)Destruction cancelled$(NC)"; \
	fi

.PHONY: output
output: ## Show Terragrunt outputs
	@echo "$(CYAN)Showing outputs for $(ENVIRONMENT) in $(AWS_REGION)...$(NC)"
	@$(call run_terragrunt,output)

.PHONY: state-list
state-list: ## List resources in Terraform state
	@echo "$(CYAN)Listing state resources for $(ENVIRONMENT) in $(AWS_REGION)...$(NC)"
	@$(call run_terragrunt,state list)

.PHONY: refresh
refresh: ## Refresh Terraform state
	@echo "$(CYAN)Refreshing state for $(ENVIRONMENT) in $(AWS_REGION)...$(NC)"
	@$(call run_terragrunt,refresh)

# =============================================================================
# MULTI-ENVIRONMENT OPERATIONS
# =============================================================================

.PHONY: plan-all
plan-all: ## Plan all environments
	@echo "$(CYAN)Planning all environments...$(NC)"
	@for env in dev staging prod; do \
		echo "$(YELLOW)Planning $$env...$(NC)"; \
		$(MAKE) plan ENVIRONMENT=$$env AWS_REGION=$(AWS_REGION) || exit 1; \
	done

.PHONY: apply-dev
apply-dev: ## Apply development environment
	@$(MAKE) apply ENVIRONMENT=dev AWS_REGION=$(AWS_REGION)

.PHONY: apply-staging
apply-staging: ## Apply staging environment
	@$(MAKE) apply ENVIRONMENT=staging AWS_REGION=$(AWS_REGION)

.PHONY: apply-prod
apply-prod: ## Apply production environment (requires confirmation)
	@echo "$(RED)PRODUCTION DEPLOYMENT$(NC)"
	@read -p "Confirm production deployment (type 'DEPLOY'): " confirm; \
	if [ "$$confirm" = "DEPLOY" ]; then \
		$(MAKE) apply ENVIRONMENT=prod AWS_REGION=$(AWS_REGION); \
	else \
		echo "$(YELLOW)Production deployment cancelled$(NC)"; \
	fi

# =============================================================================
# TESTING AND VALIDATION
# =============================================================================

.PHONY: test
test: lint security-scan policy-check ## Run all tests
	@echo "$(GREEN)All tests passed$(NC)"

.PHONY: smoke-test
smoke-test: ## Run smoke tests after deployment
	@echo "$(CYAN)Running smoke tests...$(NC)"
	@./scripts/smoke-tests.sh $(ENVIRONMENT) $(AWS_REGION)

.PHONY: integration-test
integration-test: ## Run integration tests
	@echo "$(CYAN)Running integration tests...$(NC)"
	@./scripts/integration-tests.sh $(ENVIRONMENT) $(AWS_REGION)

# =============================================================================
# DOCUMENTATION
# =============================================================================

.PHONY: docs
docs: ## Generate documentation
	@echo "$(CYAN)Generating documentation...$(NC)"
	@terraform-docs markdown table --output-file README.md --output-mode inject .
	@find . -name "*.hcl" -path "./aws/*" -exec dirname {} \; | sort -u | while read -r dir; do \
		if [ -f "$$dir/terragrunt.hcl" ]; then \
			echo "Generating docs for $$dir"; \
			terraform-docs markdown table --output-file "$$dir/README.md" "$$dir"; \
		fi; \
	done
	@echo "$(GREEN)Documentation generated$(NC)"

# =============================================================================
# INFRASTRUCTURE DIAGRAMS
# =============================================================================

.PHONY: install-diagram-tools
install-diagram-tools: ## Install tools for diagram generation
	@echo "$(CYAN)Installing diagram generation tools...$(NC)"
	@if command -v pip >/dev/null 2>&1; then \
		pip install blastradius terraform-visual graphviz; \
	else \
		echo "$(RED)Python pip not found. Please install Python first.$(NC)"; \
		exit 1; \
	fi
	@if command -v dot >/dev/null 2>&1; then \
		echo "$(GREEN)Graphviz already installed$(NC)"; \
	else \
		echo "$(YELLOW)Please install Graphviz manually:$(NC)"; \
		echo "  Windows: choco install graphviz"; \
		echo "  macOS:   brew install graphviz"; \
		echo "  Linux:   sudo apt-get install graphviz"; \
	fi
	@echo "$(GREEN)Diagram tools installation completed$(NC)"

.PHONY: check-diagram-prereqs
check-diagram-prereqs: ## Check if diagram tools are installed
	@echo "$(CYAN)Checking diagram prerequisites...$(NC)"
	@command -v terraform >/dev/null 2>&1 || (echo "$(RED)Terraform not found$(NC)" && exit 1)
	@command -v terragrunt >/dev/null 2>&1 || (echo "$(RED)Terragrunt not found$(NC)" && exit 1)
	@command -v blast-radius >/dev/null 2>&1 || (echo "$(RED)blast-radius not found. Run: make install-diagram-tools$(NC)" && exit 1)
	@command -v dot >/dev/null 2>&1 || (echo "$(RED)Graphviz not found. Please install Graphviz$(NC)" && exit 1)
	@echo "$(GREEN)All diagram prerequisites are met$(NC)"

.PHONY: diagrams
diagrams: check-diagram-prereqs ## Generate infrastructure diagrams
	@echo "$(CYAN)Generating infrastructure diagrams for $(ENVIRONMENT) in $(AWS_REGION)...$(NC)"
	@./scripts/generate-diagrams.ps1 generate $(ENVIRONMENT) $(AWS_REGION)

.PHONY: diagram-all
diagram-all: check-diagram-prereqs ## Generate diagrams for all environments and regions
	@echo "$(CYAN)Generating diagrams for all environments and regions...$(NC)"
	@./scripts/generate-diagrams.ps1 generate-all

.PHONY: serve-diagram
serve-diagram: check-diagram-prereqs ## Start interactive diagram server
	@echo "$(CYAN)Starting interactive diagram server for $(ENVIRONMENT) in $(AWS_REGION)...$(NC)"
	@./scripts/generate-diagrams.ps1 serve $(ENVIRONMENT) $(AWS_REGION)

.PHONY: diagram-index
diagram-index: ## Generate HTML index of all diagrams
	@echo "$(CYAN)Generating diagram index...$(NC)"
	@./scripts/generate-diagrams.ps1 generate-index

# =============================================================================
# CLEANUP AND MAINTENANCE
# =============================================================================

.PHONY: clean
clean: ## Clean temporary files and caches
	@echo "$(CYAN)Cleaning temporary files...$(NC)"
	@find . -type d -name ".terragrunt-cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.tfplan" -delete 2>/dev/null || true
	@find . -name "*.tfstate*" -not -path "*/.terraform/*" -delete 2>/dev/null || true
	@echo "$(GREEN)Cleanup completed$(NC)"

.PHONY: deep-clean
deep-clean: clean ## Deep clean including downloaded modules
	@echo "$(CYAN)Deep cleaning...$(NC)"
	@find . -type d -name ".terraform.d" -exec rm -rf {} + 2>/dev/null || true
	@rm -rf ~/.terragrunt-cache 2>/dev/null || true
	@echo "$(GREEN)Deep cleanup completed$(NC)"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Function to run terragrunt commands
define run_terragrunt
	@if [ "$(COMPONENT)" = "all" ]; then \
		if [ -d "aws/$(AWS_REGION)/$(ENVIRONMENT)" ]; then \
			cd "aws/$(AWS_REGION)/$(ENVIRONMENT)" && \
			terragrunt run-all $(1) \
				--terragrunt-non-interactive \
				--terragrunt-parallelism 5; \
		else \
			echo "$(RED)Directory aws/$(AWS_REGION)/$(ENVIRONMENT) not found$(NC)"; \
			exit 1; \
		fi; \
	else \
		if [ -d "aws/$(AWS_REGION)/$(ENVIRONMENT)/$(COMPONENT)" ]; then \
			cd "aws/$(AWS_REGION)/$(ENVIRONMENT)/$(COMPONENT)" && \
			terragrunt $(1) --terragrunt-non-interactive; \
		else \
			echo "$(RED)Directory aws/$(AWS_REGION)/$(ENVIRONMENT)/$(COMPONENT) not found$(NC)"; \
			exit 1; \
		fi; \
	fi
endef

# =============================================================================
# CONTINUOUS INTEGRATION TARGETS
# =============================================================================

.PHONY: ci-validate
ci-validate: format-check validate security-scan ## CI validation pipeline
	@echo "$(GREEN)CI validation completed$(NC)"

.PHONY: ci-plan
ci-plan: ci-validate plan ## CI planning pipeline
	@echo "$(GREEN)CI planning completed$(NC)"

.PHONY: ci-apply
ci-apply: ci-plan apply ## CI deployment pipeline
	@echo "$(GREEN)CI deployment completed$(NC)"

# =============================================================================
# DEVELOPMENT HELPERS
# =============================================================================

.PHONY: dev-env
dev-env: ## Setup development environment quickly
	@$(MAKE) setup
	@$(MAKE) init ENVIRONMENT=dev
	@echo "$(GREEN)Development environment ready$(NC)"

.PHONY: graph
graph: ## Generate dependency graph
	@echo "$(CYAN)Generating dependency graph...$(NC)"
	@cd "aws/$(AWS_REGION)/$(ENVIRONMENT)" && \
	terragrunt graph-dependencies | dot -Tpng > dependency-graph.png
	@echo "$(GREEN)Dependency graph saved as dependency-graph.png$(NC)"

.PHONY: check-drift
check-drift: ## Check for configuration drift
	@echo "$(CYAN)Checking for configuration drift...$(NC)"
	@$(call run_terragrunt,plan -detailed-exitcode)

# =============================================================================
# EMERGENCY PROCEDURES
# =============================================================================

.PHONY: emergency-lock
emergency-lock: ## Emergency: Lock all state files
	@echo "$(RED)EMERGENCY: Locking all state files$(NC)"
	@find aws -name "terragrunt.hcl" | while read -r file; do \
		cd "$$(dirname "$$file")"; \
		terragrunt force-unlock --terragrunt-non-interactive || true; \
		cd - > /dev/null; \
	done

.PHONY: emergency-unlock
emergency-unlock: ## Emergency: Unlock state files (provide LOCK_ID)
	@echo "$(RED)EMERGENCY: Unlocking state files$(NC)"
	@if [ -z "$(LOCK_ID)" ]; then \
		echo "$(RED)Error: LOCK_ID required. Usage: make emergency-unlock LOCK_ID=<lock-id>$(NC)"; \
		exit 1; \
	fi
	@cd "aws/$(AWS_REGION)/$(ENVIRONMENT)" && \
	terragrunt force-unlock $(LOCK_ID) --terragrunt-non-interactive

# Show current directory structure for debugging
.PHONY: show-structure
show-structure: ## Show current infrastructure directory structure
	@echo "$(CYAN)Current infrastructure structure:$(NC)"
	@find aws -type f -name "terragrunt.hcl" | head -20

# =============================================================================
# VERSION MANAGEMENT
# =============================================================================

.PHONY: check-versions
check-versions: ## Check versions of all installed tools
	@echo "$(CYAN)Checking tool versions...$(NC)"
	@echo "$(YELLOW)Expected versions:$(NC)"
	@echo "  Terraform: $(TERRAFORM_VERSION)"
	@echo "  Terragrunt: $(TERRAGRUNT_VERSION)"
	@echo "  TFSec: $(TFSEC_VERSION)"
	@echo "  Checkov: $(CHECKOV_VERSION)"
	@echo "  Infracost: $(INFRACOST_VERSION)"
	@echo "  AWS CLI: $(AWS_CLI_VERSION)"
	@echo "  Azure CLI: $(AZURE_CLI_VERSION)"
	@echo "  GCloud CLI: $(GCLOUD_CLI_VERSION)"
	@echo ""
	@echo "$(YELLOW)Installed versions:$(NC)"
	@terraform --version 2>/dev/null | head -1 || echo "  Terraform: $(RED)Not installed$(NC)"
	@terragrunt --version 2>/dev/null || echo "  Terragrunt: $(RED)Not installed$(NC)"
	@tfsec --version 2>/dev/null || echo "  TFSec: $(RED)Not installed$(NC)"
	@checkov --version 2>/dev/null || echo "  Checkov: $(RED)Not installed$(NC)"
	@infracost --version 2>/dev/null || echo "  Infracost: $(RED)Not installed$(NC)"
	@aws --version 2>/dev/null || echo "  AWS CLI: $(RED)Not installed$(NC)"
	@az --version 2>/dev/null | head -1 || echo "  Azure CLI: $(RED)Not installed$(NC)"
	@gcloud --version 2>/dev/null | head -1 || echo "  GCloud CLI: $(RED)Not installed$(NC)"

.PHONY: update-versions
update-versions: ## Update tool versions in configuration files
	@echo "$(CYAN)Updating version references...$(NC)"
	@sed -i.bak 's/required_version = ">= [0-9.]*"/required_version = ">= $(TERRAFORM_VERSION)"/' root.hcl
	@sed -i.bak 's/version = "~> [0-9.]*"/version = "~> 5.67"/' root.hcl
	@echo "$(GREEN)Version references updated$(NC)"

.PHONY: test-versions
test-versions: ## Test compatibility with current versions
	@echo "$(CYAN)Testing version compatibility...$(NC)"
	@terragrunt --version | grep -q "$(TERRAGRUNT_VERSION)" || echo "$(YELLOW)Terragrunt version mismatch$(NC)"
	@terraform --version | grep -q "$(TERRAFORM_VERSION)" || echo "$(YELLOW)Terraform version mismatch$(NC)"
	@echo "$(GREEN)Version compatibility check complete$(NC)"

.PHONY: upgrade-providers
upgrade-providers: ## Upgrade all provider versions
	@echo "$(CYAN)Upgrading provider versions...$(NC)"
	@find . -name "terragrunt.hcl" -exec dirname {} \; | while read -r dir; do \
		if [ -f "$$dir/terragrunt.hcl" ]; then \
			echo "Upgrading providers in $$dir"; \
			cd "$$dir" && terragrunt init -upgrade && cd - > /dev/null; \
		fi; \
	done
	@echo "$(GREEN)Provider upgrades complete$(NC)"

.PHONY: check-deprecated
check-deprecated: ## Check for deprecated features and syntax
	@echo "$(CYAN)Checking for deprecated features...$(NC)"
	@grep -r "provider\." aws/ gcp/ azure/ || echo "$(GREEN)No deprecated provider syntax found$(NC)"
	@grep -r "terraform\s*{" aws/ gcp/ azure/ | grep -v "required_providers" || echo "$(GREEN)No deprecated terraform blocks found$(NC)"
	@echo "$(GREEN)Deprecation check complete$(NC)"

.PHONY: migration-summary
migration-summary: ## Show summary of recent migrations
	@echo "$(CYAN)Recent Migration Summary$(NC)"
	@echo "$(CYAN)========================$(NC)"
	@echo ""
	@echo "$(YELLOW)Terragrunt: v0.53 → v0.67$(NC)"
	@echo "  ✓ Enhanced dependency management"
	@echo "  ✓ Improved caching"
	@echo "  ✓ OIDC authentication support"
	@echo ""
	@echo "$(YELLOW)AWS Provider: v5.31 → v5.67$(NC)"
	@echo "  ✓ New AWS services support"
	@echo "  ✓ Enhanced security features"
	@echo "  ✓ Performance improvements"
	@echo ""
	@echo "$(YELLOW)Azure Provider: v3.85 → v4.3$(NC)"
	@echo "  ✓ Container Apps support"
	@echo "  ✓ Enhanced Key Vault integration"
	@echo "  ✓ Improved resource management"
	@echo ""
	@echo "$(YELLOW)GCP Provider: v5.10 → v6.8$(NC)"
	@echo "  ✓ Vertex AI support"
	@echo "  ✓ Enhanced GKE features"
	@echo "  ✓ Better IAM management"
