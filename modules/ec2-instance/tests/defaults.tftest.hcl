# Runs entirely against a mocked AWS provider: no credentials, no API calls.
# The data sources return the fixed values below instead of random strings.

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

run "imdsv2_is_required" {
  command = plan

  assert {
    condition     = aws_instance.this.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required (http_tokens = required)."
  }

  assert {
    condition     = aws_instance.this.metadata_options[0].http_put_response_hop_limit == 1
    error_message = "The IMDS hop limit should default to 1."
  }
}

run "root_volume_is_encrypted_gp3" {
  command = plan

  assert {
    condition     = aws_instance.this.root_block_device[0].encrypted == true
    error_message = "The root volume must be encrypted."
  }

  assert {
    condition     = aws_instance.this.root_block_device[0].volume_type == "gp3"
    error_message = "The root volume must be gp3."
  }

  assert {
    condition     = aws_instance.this.root_block_device[0].volume_size == 20
    error_message = "The root volume should default to 20 GiB."
  }
}

run "no_ssh_by_default" {
  command = plan

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.ssh) == 0
    error_message = "No SSH ingress rule should exist by default."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.custom) == 0
    error_message = "No ingress rules of any kind should exist by default."
  }

  assert {
    condition     = aws_instance.this.associate_public_ip_address == false
    error_message = "The instance should not get a public IP by default."
  }
}

run "session_manager_role_is_attached" {
  command = apply

  assert {
    condition     = aws_iam_role_policy_attachment.ssm_core.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "The instance role must carry AmazonSSMManagedInstanceCore."
  }

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Principal.Service == "ec2.amazonaws.com"
    error_message = "Only EC2 may assume the instance role."
  }

  assert {
    condition     = aws_instance.this.iam_instance_profile == aws_iam_instance_profile.this.name
    error_message = "The instance must use the module's instance profile."
  }
}

run "uses_al2023_arm64_from_ssm" {
  command = plan

  assert {
    condition     = data.aws_ssm_parameter.al2023[0].name == "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
    error_message = "The AMI should come from the AL2023 arm64 SSM parameter."
  }

  assert {
    condition     = aws_instance.this.ami == "ami-0123456789abcdef0"
    error_message = "The instance should use the AMI resolved from SSM."
  }

  assert {
    condition     = aws_instance.this.instance_type == "t4g.micro"
    error_message = "The default instance type should be t4g.micro."
  }
}

run "security_group_lives_in_subnet_vpc" {
  command = plan

  assert {
    condition     = aws_security_group.this.vpc_id == "vpc-0a1b2c3d4e5f60718"
    error_message = "The security group must be created in the subnet's VPC."
  }

  assert {
    condition     = length(aws_eip.this) == 0
    error_message = "No Elastic IP should be allocated by default."
  }
}
