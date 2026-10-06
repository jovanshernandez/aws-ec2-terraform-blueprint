variable "name" {
  description = "Name for the instance. Used as the Name tag and as the prefix for the security group and IAM role."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$", var.name))
    error_message = "name must be 3-40 characters of lowercase letters, digits and hyphens, and must not start or end with a hyphen."
  }
}

variable "subnet_id" {
  description = "ID of the subnet to launch the instance in. The security group is created in this subnet's VPC."
  type        = string

  validation {
    condition     = can(regex("^subnet-[0-9a-f]{8,17}$", var.subnet_id))
    error_message = "subnet_id must look like subnet-0123456789abcdef0."
  }
}

variable "architecture" {
  description = "CPU architecture of the Amazon Linux 2023 AMI: arm64 (Graviton) or x86_64."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.architecture)
    error_message = "architecture must be arm64 or x86_64."
  }
}

variable "instance_type" {
  description = "EC2 instance type. Must match architecture: Graviton families (t4g, m7g, c7gn, ...) for arm64, others for x86_64."
  type        = string
  default     = "t4g.micro"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*\\.[a-z0-9]+$", var.instance_type))
    error_message = "instance_type must look like family.size, for example t4g.micro."
  }

  validation {
    condition = (
      var.architecture == "arm64"
      ? can(regex("^[a-z]+[0-9]+g", var.instance_type))
      : !can(regex("^[a-z]+[0-9]+g", var.instance_type))
    )
    error_message = "instance_type does not match architecture: use a Graviton type (t4g, m7g, c7g, ...) for arm64 and a non-Graviton type for x86_64."
  }
}

variable "ami_id" {
  description = "Optional AMI ID. When null, the latest Amazon Linux 2023 AMI for the architecture is read from the public SSM parameter."
  type        = string
  default     = null

  validation {
    condition     = var.ami_id == null || can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "ami_id must be null or look like ami-0123456789abcdef0."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 1024
    error_message = "root_volume_size must be between 8 and 1024 GiB."
  }
}

variable "root_volume_kms_key_id" {
  description = "Optional KMS key ARN for the root volume. When null, the account's default EBS key is used. The volume is encrypted either way."
  type        = string
  default     = null
}

variable "metadata_hop_limit" {
  description = "IMDSv2 PUT response hop limit. Keep 1 unless containers on the host need instance metadata (then 2)."
  type        = number
  default     = 1

  validation {
    condition     = var.metadata_hop_limit >= 1 && var.metadata_hop_limit <= 64
    error_message = "metadata_hop_limit must be between 1 and 64."
  }
}

variable "associate_public_ip_address" {
  description = "Give the instance a public IPv4 address. Without one, Session Manager needs a NAT gateway or SSM VPC endpoints."
  type        = bool
  default     = false
}

variable "create_eip" {
  description = "Allocate an Elastic IP and associate it with the instance."
  type        = bool
  default     = false
}

variable "ingress_rules" {
  description = "Extra inbound rules for application traffic, keyed by a short name. SSH (port 22) is not allowed here; use ssh_ingress_cidrs."
  type = map(object({
    from_port   = number
    to_port     = number
    cidr_ipv4   = string
    ip_protocol = optional(string, "tcp")
    description = optional(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for r in values(var.ingress_rules) : can(cidrhost(r.cidr_ipv4, 0))])
    error_message = "Every ingress_rules entry needs a valid IPv4 CIDR in cidr_ipv4."
  }

  validation {
    condition     = alltrue([for r in values(var.ingress_rules) : !(r.from_port <= 22 && r.to_port >= 22)])
    error_message = "ingress_rules must not include port 22. Use ssh_ingress_cidrs for SSH."
  }
}

variable "ssh_ingress_cidrs" {
  description = "CIDR blocks allowed to reach SSH on port 22. Empty (the default) means no SSH ingress; use Session Manager instead."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.ssh_ingress_cidrs : can(cidrhost(c, 0))])
    error_message = "ssh_ingress_cidrs must contain valid IPv4 CIDR blocks."
  }

  validation {
    condition     = alltrue([for c in var.ssh_ingress_cidrs : !can(cidrhost(c, 0)) || split("/", c)[1] != "0"])
    error_message = "ssh_ingress_cidrs must not open SSH to the internet (no /0 ranges such as 0.0.0.0/0)."
  }
}

variable "key_name" {
  description = "Optional EC2 key pair name. Only useful together with ssh_ingress_cidrs."
  type        = string
  default     = null
}

variable "egress_cidr" {
  description = "IPv4 CIDR the instance may reach on all ports. Session Manager needs HTTPS to the SSM endpoints."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.egress_cidr, 0))
    error_message = "egress_cidr must be a valid IPv4 CIDR block."
  }
}

variable "user_data" {
  description = "Optional cloud-init user data (plain text, not base64). Changing it replaces the instance."
  type        = string
  default     = null

  validation {
    condition     = var.user_data == null || length(coalesce(var.user_data, " ")) <= 16384
    error_message = "user_data must be 16 KB or less."
  }
}

variable "additional_iam_policy_arns" {
  description = "Extra managed policy ARNs to attach to the instance role, on top of AmazonSSMManagedInstanceCore."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for a in var.additional_iam_policy_arns : can(regex("^arn:aws[a-z-]*:iam::(aws|[0-9]{12}):policy/.+$", a))])
    error_message = "additional_iam_policy_arns must be IAM policy ARNs."
  }
}

variable "detailed_monitoring" {
  description = "Enable 1-minute CloudWatch detailed monitoring (billed)."
  type        = bool
  default     = false
}

variable "termination_protection" {
  description = "Enable EC2 API termination protection."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags added to every resource the module creates. Prefer provider default_tags for org-wide tags."
  type        = map(string)
  default     = {}
}
