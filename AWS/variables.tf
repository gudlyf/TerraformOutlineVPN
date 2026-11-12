variable "region" {
  description = "AWS region to deploy the Outline server in."
  type        = string
  default     = "ca-central-1"
}

variable "name" {
  description = "Name for the server and prefix for every resource created."
  type        = string
  default     = "outline"
}

variable "server_name" {
  description = "Display name shown in Outline Manager. Defaults to \"Outline (<region>)\"."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type (must support x86_64)."
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Existing public subnet to use. Leave null to create a dedicated VPC."
  type        = string
  default     = null
}

variable "api_port" {
  description = "Management API port. Leave null for a random port."
  type        = number
  default     = null
}

variable "keys_port" {
  description = "Access-key port (TCP and UDP). Leave null for a random port."
  type        = number
  default     = null
}

variable "management_cidr_blocks" {
  description = "IPv4 CIDRs allowed to reach the management API. Set this to your own IP (x.x.x.x/32) if you can."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "access_cidr_blocks" {
  description = "IPv4 CIDRs allowed to use the VPN."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_ssm_session_manager" {
  description = "Allow shell access through AWS Systems Manager Session Manager."
  type        = bool
  default     = true
}

variable "ssh_key_name" {
  description = "Existing EC2 key pair for SSH. Leave null to disable SSH."
  type        = string
  default     = null
}

variable "ssh_cidr_blocks" {
  description = "IPv4 CIDRs allowed to SSH in (only used with ssh_key_name)."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}
