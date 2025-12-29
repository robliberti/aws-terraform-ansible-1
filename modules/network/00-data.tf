data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Use first 2 AZs for future multi-AZ expansion.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}