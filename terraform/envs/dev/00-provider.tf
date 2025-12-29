terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}

provider "aws" {
  # Region intentionally omitted.
  # Terraform will use standard AWS resolution:
  # - AWS_REGION / AWS_DEFAULT_REGION env vars, or
  # - ~/.aws/config (aws configure), or
  # - instance metadata (if running on AWS)
}