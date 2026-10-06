# Plans and "applies" the example against a mocked AWS provider to check that
# it wires the module together correctly. No credentials or API calls.

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      id = "vpc-0a1b2c3d4e5f60718"
    }
  }

  mock_data "aws_subnets" {
    defaults = {
      ids = ["subnet-0bbbbbbbbbbbbbbbb", "subnet-0aaaaaaaaaaaaaaaa"]
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

  mock_resource "aws_eip" {
    defaults = {
      public_ip = "198.51.100.10"
    }
  }

  mock_resource "aws_instance" {
    defaults = {
      id = "i-0123456789abcdef0"
    }
  }
}

run "example_wires_the_module" {
  command = apply

  assert {
    condition     = output.url == "http://198.51.100.10"
    error_message = "The example should expose the Elastic IP as its URL."
  }

  assert {
    condition     = output.ssm_start_session_command == "aws ssm start-session --target i-0123456789abcdef0"
    error_message = "The example should print the Session Manager command."
  }
}
