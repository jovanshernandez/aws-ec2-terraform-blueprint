terraform {
  # 1.9 is the first release that lets a variable validation reference other
  # variables (used to match instance_type to architecture).
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}
