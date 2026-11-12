locals {
  create_network = var.subnet_id == null

  vpc_id    = local.create_network ? aws_vpc.this[0].id : data.aws_subnet.selected[0].vpc_id
  subnet_id = local.create_network ? aws_subnet.public[0].id : var.subnet_id
}

data "aws_subnet" "selected" {
  count = local.create_network ? 0 : 1
  id    = var.subnet_id
}

# Pick an availability zone that actually offers the requested instance type.
data "aws_ec2_instance_type_offerings" "this" {
  count         = local.create_network ? 1 : 0
  location_type = "availability-zone"

  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }
}

resource "aws_vpc" "this" {
  count = local.create_network ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = local.tags
}

resource "aws_internet_gateway" "this" {
  count = local.create_network ? 1 : 0

  vpc_id = aws_vpc.this[0].id
  tags   = local.tags
}

resource "aws_subnet" "public" {
  count = local.create_network ? 1 : 0

  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = var.vpc_cidr
  availability_zone       = sort(data.aws_ec2_instance_type_offerings.this[0].locations)[0]
  map_public_ip_on_launch = false

  tags = merge(local.tags, { Name = "${var.name}-public" })
}

resource "aws_route_table" "public" {
  count = local.create_network ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = merge(local.tags, { Name = "${var.name}-public" })
}

resource "aws_route_table_association" "public" {
  count = local.create_network ? 1 : 0

  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public[0].id
}

# ----------------------------------------------------------------------------
# Security group
# ----------------------------------------------------------------------------

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = "Outline VPN server"
  vpc_id      = local.vpc_id
  tags        = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "management_api" {
  for_each = toset(var.management_cidr_blocks)

  security_group_id = aws_security_group.this.id
  description       = "Outline management API"
  ip_protocol       = "tcp"
  from_port         = local.api_port
  to_port           = local.api_port
  cidr_ipv4         = each.value
  tags              = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "access_keys" {
  for_each = {
    for pair in setproduct(["tcp", "udp"], var.access_cidr_blocks) :
    "${pair[0]}-${pair[1]}" => { protocol = pair[0], cidr = pair[1] }
  }

  security_group_id = aws_security_group.this.id
  description       = "Outline access keys (${upper(each.value.protocol)})"
  ip_protocol       = each.value.protocol
  from_port         = local.keys_port
  to_port           = local.keys_port
  cidr_ipv4         = each.value.cidr
  tags              = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = local.enable_ssh ? toset(var.ssh_cidr_blocks) : toset([])

  security_group_id = aws_security_group.this.id
  description       = "SSH"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
  tags              = local.tags
}

resource "aws_vpc_security_group_egress_rule" "all_ipv4" {
  security_group_id = aws_security_group.this.id
  description       = "Outbound traffic for VPN clients and package installs"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  tags              = local.tags
}

resource "aws_vpc_security_group_egress_rule" "all_ipv6" {
  security_group_id = aws_security_group.this.id
  description       = "Outbound IPv6 traffic"
  ip_protocol       = "-1"
  cidr_ipv6         = "::/0"
  tags              = local.tags
}
