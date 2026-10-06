output "instance_id" {
  description = "ID of the EC2 instance."
  value       = module.web.instance_id
}

output "public_ip" {
  description = "Elastic IP of the instance."
  value       = module.web.public_ip
}

output "url" {
  description = "HTTP URL of the nginx page."
  value       = "http://${module.web.public_ip}"
}

output "ssm_start_session_command" {
  description = "Command that opens a shell on the instance through Session Manager."
  value       = module.web.ssm_start_session_command
}
