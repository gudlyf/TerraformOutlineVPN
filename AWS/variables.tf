variable "profile" {}

variable "region" {
  default = "ca-central-1"
}

variable "private_key_file" {
  default = "../certs/outline"
}

variable "public_key_file" {
  default = "../certs/outline.pub"
}

variable "client_config_path" {
  default = "../client_configs"
}
