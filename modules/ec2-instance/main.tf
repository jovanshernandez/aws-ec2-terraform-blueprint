data "aws_partition" "current" {}

data "aws_subnet" "this" {
  id = var.subnet_id
}

# Latest Amazon Linux 2023 AMI, published by AWS as a public SSM parameter.
data "aws_ssm_parameter" "al2023" {
  count = var.ami_id == null ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-${var.architecture}"
}

locals {
  ami_id = var.ami_id != null ? var.ami_id : nonsensitive(data.aws_ssm_parameter.al2023[0].value)
  tags   = merge(var.tags, { Name = var.name })
}

################################################################################
# IAM: instance role for Session Manager
################################################################################

resource "aws_iam_role" "this" {
  name_prefix = "${var.name}-"
  description = "Instance role for ${var.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = var.additional_iam_policy_arns

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "this" {
  name_prefix = "${var.name}-"
  role        = aws_iam_role.this.name
  tags        = local.tags
}

################################################################################
# Security group
################################################################################

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = "Traffic policy for ${var.name}"
  vpc_id      = data.aws_subnet.this.vpc_id
  tags        = merge(local.tags, { Name = "${var.name}-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "Outbound traffic, including HTTPS to the SSM endpoints"
  ip_protocol       = "-1"
  cidr_ipv4         = var.egress_cidr
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.ssh_ingress_cidrs)

  security_group_id = aws_security_group.this.id
  description       = "SSH from ${each.value}"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "custom" {
  for_each = var.ingress_rules

  security_group_id = aws_security_group.this.id
  description       = coalesce(each.value.description, each.key)
  ip_protocol       = each.value.ip_protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  cidr_ipv4         = each.value.cidr_ipv4
}

################################################################################
# Instance
################################################################################

resource "aws_instance" "this" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = var.associate_public_ip_address
  key_name                    = var.key_name
  monitoring                  = var.detailed_monitoring
  disable_api_termination     = var.termination_protection
  ebs_optimized               = true

  user_data                   = var.user_data
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = var.metadata_hop_limit
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    kms_key_id            = var.root_volume_kms_key_id
    delete_on_termination = true
    tags                  = merge(local.tags, { Name = "${var.name}-root" })
  }

  tags = local.tags

  lifecycle {
    # A new AL2023 release changes the SSM parameter; roll instances on
    # purpose (taint or ami_id), not on every plan.
    ignore_changes = [ami]
  }
}

resource "aws_eip" "this" {
  count = var.create_eip ? 1 : 0

  domain   = "vpc"
  instance = aws_instance.this.id
  tags     = merge(local.tags, { Name = "${var.name}-eip" })
}
