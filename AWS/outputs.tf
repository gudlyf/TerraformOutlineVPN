output "public_ip" {
  description = "Elastic IP of the Outline server."
  value       = module.outline.public_ip
}

output "api_port" {
  description = "Management API port (TCP)."
  value       = module.outline.api_port
}

output "keys_port" {
  description = "Access-key port (TCP and UDP)."
  value       = module.outline.keys_port
}

output "instance_id" {
  description = "EC2 instance ID."
  value       = module.outline.instance_id
}

output "manager_config_command" {
  description = "Run this a few minutes after apply to get the JSON for Outline Manager."
  value       = module.outline.manager_config_command
}

output "session_manager_command" {
  description = "Open a shell on the server via Session Manager."
  value       = module.outline.session_manager_command
}

output "security_group_id" {
  description = "Security group attached to the server."
  value       = module.outline.security_group_id
}
