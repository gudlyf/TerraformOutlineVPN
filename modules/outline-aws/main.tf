data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "al2023" {
  count = var.ami_id == null ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_ec2_instance_type" "this" {
  instance_type = var.instance_type
}

locals {
  region      = data.aws_region.current.region
  ami_id      = var.ami_id != null ? var.ami_id : data.aws_ssm_parameter.al2023[0].insecure_value
  server_name = coalesce(var.server_name, "Outline (${local.region})")

  api_port  = coalesce(var.api_port, random_integer.api_port.result)
  keys_port = coalesce(var.keys_port, random_integer.keys_port.result)

  manager_config_parameter_name = coalesce(var.manager_config_parameter_name, "/${var.name}/outline-manager-config")
  manager_config_parameter_arn  = "arn:${data.aws_partition.current.partition}:ssm:${local.region}:${data.aws_caller_identity.current.account_id}:parameter/${trimprefix(local.manager_config_parameter_name, "/")}"

  enable_ssh = var.ssh_key_name != null && length(var.ssh_cidr_blocks) > 0

  tags = merge(var.tags, { Name = var.name })
}

# Ports are chosen once and then kept in state, so they never change on later
# applies. The two ranges don't overlap, so the ports can never collide, and
# both sit below the Linux ephemeral port range.
resource "random_integer" "api_port" {
  min = 1024
  max = 16383
  keepers = {
    name = var.name
  }
}

resource "random_integer" "keys_port" {
  min = 16384
  max = 32767
  keepers = {
    name = var.name
  }
}

# The Elastic IP is allocated before the instance so its address can be baked
# into the Outline config. Outline embeds this hostname in every access key, so
# it must not change for the life of the server.
resource "aws_eip" "this" {
  domain = "vpc"
  tags   = local.tags

  depends_on = [aws_internet_gateway.this]
}

resource "aws_instance" "this" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  key_name                    = local.enable_ssh ? var.ssh_key_name : null
  associate_public_ip_address = false

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    public_ip                     = aws_eip.this.public_ip
    api_port                      = local.api_port
    keys_port                     = local.keys_port
    server_name_b64               = base64encode(local.server_name)
    install_script_ref            = var.install_script_ref
    region                        = local.region
    manager_config_parameter_name = local.manager_config_parameter_name
  })

  # The installer only runs on first boot, so any change to the rendered user
  # data (ports, Elastic IP, installer version) means a fresh server.
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
    tags                  = local.tags
  }

  dynamic "credit_specification" {
    for_each = data.aws_ec2_instance_type.this.burstable_performance_supported ? [1] : []
    content {
      cpu_credits = var.burstable_cpu_credits
    }
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [
      # A newer AMI would otherwise replace the instance and wipe every access key.
      ami,
      # The instance launches without a public IP, but once the Elastic IP is
      # attached the provider reads this back as true. It is ForceNew, so without
      # this every apply after the first would replace the server.
      associate_public_ip_address,
    ]

    precondition {
      condition     = contains(data.aws_ec2_instance_type.this.supported_architectures, "x86_64")
      error_message = "instance_type ${var.instance_type} does not support x86_64. The Outline server image (quay.io/outline/shadowbox) is published for amd64 only."
    }

    precondition {
      condition     = local.api_port != local.keys_port
      error_message = "api_port and keys_port must be different."
    }
  }
}

resource "aws_eip_association" "this" {
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this.id
}
