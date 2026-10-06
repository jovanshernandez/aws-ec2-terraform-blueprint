# Launches one AL2023 Graviton instance in the account's default VPC, serving
# a static page with nginx. Shell access is through Session Manager; no SSH
# port is opened and no key pair is used.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

module "web" {
  source = "../../modules/ec2-instance"

  name          = var.name
  subnet_id     = sort(data.aws_subnets.default.ids)[0]
  instance_type = var.instance_type

  # The default VPC has no NAT gateway, so the instance needs a public
  # address to reach the SSM endpoints and the package mirrors.
  associate_public_ip_address = true
  create_eip                  = true

  ingress_rules = var.http_ingress_cidr == null ? {} : {
    http = {
      from_port   = 80
      to_port     = 80
      cidr_ipv4   = var.http_ingress_cidr
      description = "HTTP"
    }
  }

  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    dnf -y install nginx
    echo "<h1>${var.name}</h1><p>Served from AL2023 on Graviton.</p>" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOT
}
