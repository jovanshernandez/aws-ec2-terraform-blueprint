# Optional features: x86_64 with a pinned AMI, SSH from a narrow range,
# app ingress, Elastic IP and user data.

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_subnet" {
    defaults = {
      vpc_id = "vpc-0a1b2c3d4e5f60718"
    }
  }

  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-0123456789abcdef0"
    }
  }
}

variables {
  name      = "blueprint-test"
  subnet_id = "subnet-0a1b2c3d4e5f60718"
}

run "x86_64_with_pinned_ami" {
  command = plan

  variables {
    architecture  = "x86_64"
    instance_type = "t3.micro"
    ami_id        = "ami-0fedcba9876543210"
  }

  assert {
    condition     = length(data.aws_ssm_parameter.al2023) == 0
    error_message = "The SSM lookup should be skipped when ami_id is set."
  }

  assert {
    condition     = aws_instance.this.ami == "ami-0fedcba9876543210"
    error_message = "The pinned AMI should be used."
  }
}

run "ssh_from_a_single_address" {
  command = plan

  variables {
    ssh_ingress_cidrs = ["203.0.113.10/32"]
    key_name          = "ops"
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.ssh) == 1
    error_message = "Expected exactly one SSH rule."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.ssh["203.0.113.10/32"].from_port == 22
    error_message = "The SSH rule must be on port 22."
  }

  assert {
    condition     = aws_instance.this.key_name == "ops"
    error_message = "The key pair should be attached when provided."
  }
}

run "https_ingress_rule" {
  command = plan

  variables {
    ingress_rules = {
      https = { from_port = 443, to_port = 443, cidr_ipv4 = "0.0.0.0/0" }
    }
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.custom["https"].ip_protocol == "tcp"
    error_message = "ip_protocol should default to tcp."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.custom["https"].description == "https"
    error_message = "The rule key should be used as the description when none is given."
  }
}

run "elastic_ip_and_user_data" {
  command = apply

  variables {
    create_eip = true
    user_data  = "#!/bin/bash\ndnf -y install nginx && systemctl enable --now nginx\n"
  }

  assert {
    condition     = aws_eip.this[0].domain == "vpc"
    error_message = "The Elastic IP should be a VPC address."
  }

  assert {
    condition     = aws_eip.this[0].instance == aws_instance.this.id
    error_message = "The Elastic IP should be associated with the instance."
  }

  assert {
    condition     = output.public_ip == aws_eip.this[0].public_ip
    error_message = "public_ip should report the Elastic IP when one is created."
  }

  assert {
    condition     = aws_instance.this.user_data_replace_on_change == true
    error_message = "Changing user data should replace the instance."
  }
}

run "extra_policies_are_attached" {
  command = plan

  variables {
    additional_iam_policy_arns = ["arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.additional) == 1
    error_message = "Each extra policy ARN should get an attachment."
  }
}
