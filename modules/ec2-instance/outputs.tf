output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "ARN of the EC2 instance."
  value       = aws_instance.this.arn
}

output "ami_id" {
  description = "AMI the instance was launched from."
  value       = aws_instance.this.ami
}

output "private_ip" {
  description = "Private IPv4 address of the instance."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IPv4 address: the Elastic IP when create_eip is true, otherwise the instance's public IP (empty if it has none)."
  value       = var.create_eip ? aws_eip.this[0].public_ip : aws_instance.this.public_ip
}

output "security_group_id" {
  description = "ID of the security group attached to the instance."
  value       = aws_security_group.this.id
}

output "iam_role_name" {
  description = "Name of the instance IAM role. Attach extra policies to it from the caller if needed."
  value       = aws_iam_role.this.name
}

output "iam_role_arn" {
  description = "ARN of the instance IAM role."
  value       = aws_iam_role.this.arn
}

output "instance_profile_name" {
  description = "Name of the instance profile."
  value       = aws_iam_instance_profile.this.name
}

output "ssm_start_session_command" {
  description = "AWS CLI command that opens a shell on the instance through Session Manager."
  value       = "aws ssm start-session --target ${aws_instance.this.id}"
}
