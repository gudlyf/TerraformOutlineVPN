output "instance_id" {
  description = "ID of the Outline EC2 instance."
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Elastic IP of the Outline server. Access keys point at this address."
  value       = aws_eip.this.public_ip
}

output "api_port" {
  description = "TCP port of the Outline management API."
  value       = local.api_port
}

output "keys_port" {
  description = "TCP/UDP port new access keys are created on."
  value       = local.keys_port
}

output "security_group_id" {
  description = "ID of the security group attached to the instance."
  value       = aws_security_group.this.id
}

output "vpc_id" {
  description = "ID of the VPC the server runs in."
  value       = local.vpc_id
}

output "subnet_id" {
  description = "ID of the subnet the server runs in."
  value       = local.subnet_id
}

output "manager_config_parameter_name" {
  description = "SSM parameter (SecureString) the instance writes the Outline Manager config to once installation finishes."
  value       = local.manager_config_parameter_name
}

output "manager_config_command" {
  description = "AWS CLI command that prints the JSON to paste into Outline Manager."
  value       = "aws ssm get-parameter --region ${local.region} --name ${local.manager_config_parameter_name} --with-decryption --query Parameter.Value --output text"
}

output "session_manager_command" {
  description = "AWS CLI command that opens a shell on the server through Session Manager (null when disabled)."
  value       = var.enable_ssm_session_manager ? "aws ssm start-session --region ${local.region} --target ${aws_instance.this.id}" : null
}
