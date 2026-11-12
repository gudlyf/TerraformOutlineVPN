variable "name" {
  description = "Name used for the instance and as a prefix for every resource the module creates."
  type        = string
  default     = "outline"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,30}$", var.name))
    error_message = "name must start with a letter, contain only letters, digits and hyphens, and be at most 31 characters."
  }
}

variable "server_name" {
  description = "Display name Outline Manager shows for this server. Defaults to \"Outline (<region>)\"."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type. Must support x86_64, because the official Outline server image is amd64 only."
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI to launch. Leave null to use the latest Amazon Linux 2023 x86_64 AMI. The user data script expects Amazon Linux 2023 (dnf)."
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Size of the encrypted gp3 root volume, in GiB."
  type        = number
  default     = 10

  validation {
    condition     = var.root_volume_size >= 8
    error_message = "root_volume_size must be at least 8 GiB (the size of the Amazon Linux 2023 AMI snapshot)."
  }
}

variable "burstable_cpu_credits" {
  description = "CPU credit option for burstable (T-family) instances: \"standard\" (never billed for extra CPU) or \"unlimited\". Ignored for other instance families."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "unlimited"], var.burstable_cpu_credits)
    error_message = "burstable_cpu_credits must be \"standard\" or \"unlimited\"."
  }
}

# ----------------------------------------------------------------------------
# Networking
# ----------------------------------------------------------------------------

variable "subnet_id" {
  description = "Existing public subnet (with a route to an internet gateway) to launch into. Leave null and the module creates a small dedicated VPC and public subnet."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated VPC. Only used when subnet_id is null."
  type        = string
  default     = "10.42.0.0/24"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "api_port" {
  description = "TCP port for the Outline management API. Leave null to pick a random port (1024-16383) once and keep it."
  type        = number
  default     = null

  validation {
    condition     = var.api_port == null || try(var.api_port >= 1 && var.api_port <= 65535 && floor(var.api_port) == var.api_port, false)
    error_message = "api_port must be an integer between 1 and 65535."
  }
}

variable "keys_port" {
  description = "TCP and UDP port new access keys are created on. Leave null to pick a random port (16384-32767) once and keep it."
  type        = number
  default     = null

  validation {
    condition     = var.keys_port == null || try(var.keys_port >= 1 && var.keys_port <= 65535 && floor(var.keys_port) == var.keys_port, false)
    error_message = "keys_port must be an integer between 1 and 65535."
  }
}

variable "management_cidr_blocks" {
  description = "IPv4 CIDR blocks allowed to reach the management API (where Outline Manager runs). The API also requires a secret URL path and a pinned TLS certificate, but narrowing this to your own IP is recommended."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for c in var.management_cidr_blocks : can(cidrhost(c, 0))])
    error_message = "management_cidr_blocks must contain valid IPv4 CIDR blocks."
  }
}

variable "access_cidr_blocks" {
  description = "IPv4 CIDR blocks allowed to connect to the access-key port (your VPN clients)."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for c in var.access_cidr_blocks : can(cidrhost(c, 0))])
    error_message = "access_cidr_blocks must contain valid IPv4 CIDR blocks."
  }
}

# ----------------------------------------------------------------------------
# Administrative access
# ----------------------------------------------------------------------------

variable "enable_ssm_session_manager" {
  description = "Attach AmazonSSMManagedInstanceCore so you can open a shell with `aws ssm start-session` (no SSH or open port needed)."
  type        = bool
  default     = true
}

variable "ssh_key_name" {
  description = "Name of an existing EC2 key pair to install for SSH. Leave null to disable SSH (Session Manager is the recommended way in)."
  type        = string
  default     = null
}

variable "ssh_cidr_blocks" {
  description = "IPv4 CIDR blocks allowed to reach port 22. Only used when ssh_key_name is set. Empty means no SSH rule."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.ssh_cidr_blocks : can(cidrhost(c, 0))])
    error_message = "ssh_cidr_blocks must contain valid IPv4 CIDR blocks."
  }
}

# ----------------------------------------------------------------------------
# Outline
# ----------------------------------------------------------------------------

variable "install_script_ref" {
  description = "Git ref (ideally a full commit SHA) of OutlineFoundation/outline-server whose install_server.sh is run on first boot. Pinning to a SHA keeps deploys reproducible."
  type        = string
  default     = "fa185b0f9002e9c556d995fdaf93adeadcf2af37"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.install_script_ref))
    error_message = "install_script_ref must be a valid git ref."
  }
}

variable "manager_config_parameter_name" {
  description = "SSM Parameter Store name the instance writes the Outline Manager config (apiUrl and certSha256) to. Defaults to /<name>/outline-manager-config."
  type        = string
  default     = null

  validation {
    condition     = var.manager_config_parameter_name == null || can(regex("^/[A-Za-z0-9_.\\-/]+$", var.manager_config_parameter_name))
    error_message = "manager_config_parameter_name must be a fully qualified parameter name starting with \"/\"."
  }
}

variable "tags" {
  description = "Tags added to every resource the module creates."
  type        = map(string)
  default     = {}
}
