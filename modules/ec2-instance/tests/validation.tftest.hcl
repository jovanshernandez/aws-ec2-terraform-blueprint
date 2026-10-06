# Bad inputs must be rejected at plan time, before anything reaches AWS.

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

run "rejects_ssh_from_anywhere" {
  command = plan

  variables {
    ssh_ingress_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.ssh_ingress_cidrs]
}

run "rejects_invalid_ssh_cidr" {
  command = plan

  variables {
    ssh_ingress_cidrs = ["10.0.0.300/32"]
  }

  expect_failures = [var.ssh_ingress_cidrs]
}

run "rejects_port_22_in_ingress_rules" {
  command = plan

  variables {
    ingress_rules = {
      sneaky = { from_port = 0, to_port = 1024, cidr_ipv4 = "0.0.0.0/0" }
    }
  }

  expect_failures = [var.ingress_rules]
}

run "rejects_x86_type_on_arm64" {
  command = plan

  variables {
    architecture  = "arm64"
    instance_type = "t3.micro"
  }

  expect_failures = [var.instance_type]
}

run "rejects_graviton_type_on_x86_64" {
  command = plan

  variables {
    architecture  = "x86_64"
    instance_type = "m7g.large"
  }

  expect_failures = [var.instance_type]
}

run "rejects_unknown_architecture" {
  command = plan

  variables {
    architecture = "sparc"
  }

  expect_failures = [var.architecture]
}

run "rejects_tiny_root_volume" {
  command = plan

  variables {
    root_volume_size = 4
  }

  expect_failures = [var.root_volume_size]
}

run "rejects_bad_name" {
  command = plan

  variables {
    name = "Bad_Name"
  }

  expect_failures = [var.name]
}

run "rejects_bad_subnet_id" {
  command = plan

  variables {
    subnet_id = "vpc-0a1b2c3d"
  }

  expect_failures = [var.subnet_id]
}

run "rejects_bad_hop_limit" {
  command = plan

  variables {
    metadata_hop_limit = 0
  }

  expect_failures = [var.metadata_hop_limit]
}
