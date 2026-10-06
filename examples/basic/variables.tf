variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile for local runs. Leave null to use the standard credential chain (env vars, SSO, instance role)."
  type        = string
  default     = null
}

variable "project" {
  description = "Project tag applied to every resource through provider default_tags."
  type        = string
  default     = "ec2-blueprint"
}

variable "environment" {
  description = "Environment tag applied to every resource through provider default_tags."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "name" {
  description = "Instance name."
  type        = string
  default     = "blueprint-web"
}

variable "instance_type" {
  description = "Graviton instance type."
  type        = string
  default     = "t4g.micro"
}

variable "http_ingress_cidr" {
  description = "IPv4 CIDR allowed to reach HTTP on port 80. Set to null to close port 80."
  type        = string
  default     = "0.0.0.0/0"
}
