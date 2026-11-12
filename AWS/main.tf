module "outline" {
  source = "../modules/outline-aws"

  name          = var.name
  server_name   = var.server_name
  instance_type = var.instance_type

  subnet_id = var.subnet_id
  api_port  = var.api_port
  keys_port = var.keys_port

  management_cidr_blocks = var.management_cidr_blocks
  access_cidr_blocks     = var.access_cidr_blocks

  enable_ssm_session_manager = var.enable_ssm_session_manager
  ssh_key_name               = var.ssh_key_name
  ssh_cidr_blocks            = var.ssh_cidr_blocks
}
