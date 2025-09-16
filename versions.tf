terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4.1"
    }
  }

  # Uncomment to use Terraform Cloud
  # cloud {
  #   organization = "serverless-api-platform"
  #
  #   workspaces {
  #     name = "api-dev"
  #   }
  # }

  # Using local backend for demonstration
  backend "local" {
    path = "terraform.tfstate"
  }
}