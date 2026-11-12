# Unit tests for the outline-aws module. They run entirely against mocked
# providers, so no AWS credentials are needed and nothing is created.
#
#   cd modules/outline-aws && terraform init && terraform test
#
# Requires Terraform >= 1.7 or OpenTofu >= 1.8 (mock providers).

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "ca-central-1"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_ssm_parameter" {
    defaults = {
      insecure_value = "ami-0123456789abcdef0"
    }
  }

  mock_data "aws_ec2_instance_type" {
    defaults = {
      supported_architectures         = ["x86_64"]
      burstable_performance_supported = true
    }
  }

  mock_data "aws_ec2_instance_type_offerings" {
    defaults = {
      locations = ["ca-central-1d", "ca-central-1a", "ca-central-1b"]
    }
  }

  mock_data "aws_subnet" {
    defaults = {
      vpc_id = "vpc-0existing0000000"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_eip" {
    defaults = {
      public_ip = "203.0.113.10"
    }
  }
}

run "defaults" {
  assert {
    condition     = length(aws_vpc.this) == 1 && length(aws_subnet.public) == 1
    error_message = "A dedicated VPC and subnet should be created when subnet_id is null."
  }

  assert {
    condition     = aws_subnet.public[0].availability_zone == "ca-central-1a"
    error_message = "The subnet should land in the first AZ (sorted) that offers the instance type."
  }

  assert {
    condition     = aws_instance.this.ami == "ami-0123456789abcdef0"
    error_message = "The AMI should come from the Amazon Linux 2023 SSM parameter."
  }

  assert {
    condition     = aws_instance.this.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required."
  }

  assert {
    condition     = aws_instance.this.root_block_device[0].encrypted && aws_instance.this.root_block_device[0].volume_type == "gp3"
    error_message = "The root volume must be encrypted gp3."
  }

  assert {
    condition     = aws_instance.this.credit_specification[0].cpu_credits == "standard"
    error_message = "Burstable instances should default to standard CPU credits."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.ssh) == 0
    error_message = "SSH should be disabled by default."
  }

  assert {
    condition     = output.api_port >= 1024 && output.api_port <= 16383
    error_message = "The random API port should come from the 1024-16383 range."
  }

  assert {
    condition     = output.keys_port >= 16384 && output.keys_port <= 32767
    error_message = "The random keys port should come from the 16384-32767 range."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.access_keys) == 2
    error_message = "Access keys need one TCP and one UDP rule per CIDR."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.management_api["0.0.0.0/0"].from_port == output.api_port
    error_message = "The management rule should open exactly the API port."
  }

  assert {
    condition     = output.manager_config_parameter_name == "/outline/outline-manager-config"
    error_message = "Unexpected default parameter name."
  }

  assert {
    condition     = strcontains(aws_instance.this.user_data, "readonly PUBLIC_IP=\"203.0.113.10\"")
    error_message = "User data should be rendered with the Elastic IP."
  }

  assert {
    condition     = strcontains(aws_instance.this.user_data, "readonly KEYS_PORT=\"${output.keys_port}\"")
    error_message = "User data should be rendered with the keys port."
  }

  assert {
    condition     = strcontains(aws_instance.this.user_data, "base64 --decode") && strcontains(aws_instance.this.user_data, base64encode("Outline (ca-central-1)"))
    error_message = "The default server name should be passed base64-encoded."
  }

  assert {
    condition     = output.session_manager_command != null
    error_message = "Session Manager should be enabled by default."
  }
}

run "existing_subnet_fixed_ports_and_ssh" {
  variables {
    name                   = "vpn"
    server_name            = "Bob's \"VPN\""
    subnet_id              = "subnet-0123456789abcdef0"
    api_port               = 8443
    keys_port              = 443
    management_cidr_blocks = ["198.51.100.7/32"]
    access_cidr_blocks     = ["0.0.0.0/0", "192.0.2.0/24"]
    ssh_key_name           = "my-key"
    ssh_cidr_blocks        = ["198.51.100.7/32"]

    enable_ssm_session_manager = false
  }

  assert {
    condition     = length(aws_vpc.this) == 0 && output.vpc_id == "vpc-0existing0000000" && output.subnet_id == "subnet-0123456789abcdef0"
    error_message = "No VPC should be created when subnet_id is supplied."
  }

  assert {
    condition     = output.api_port == 8443 && output.keys_port == 443
    error_message = "Explicit ports should be used as-is."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.access_keys) == 4
    error_message = "Two access CIDRs should produce four rules (TCP and UDP each)."
  }

  assert {
    condition     = aws_instance.this.key_name == "my-key" && length(aws_vpc_security_group_ingress_rule.ssh) == 1
    error_message = "SSH should be enabled when a key and CIDRs are provided."
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.ssm_core) == 0 && output.session_manager_command == null
    error_message = "Session Manager should be off when disabled."
  }

  assert {
    condition     = strcontains(aws_instance.this.user_data, base64encode("Bob's \"VPN\""))
    error_message = "Server names with quotes should survive via base64."
  }

  assert {
    condition     = output.manager_config_parameter_name == "/vpn/outline-manager-config"
    error_message = "The parameter name should follow var.name."
  }
}

run "ssh_key_without_cidrs_stays_closed" {
  variables {
    ssh_key_name = "my-key"
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.ssh) == 0
    error_message = "SSH must stay closed unless ssh_cidr_blocks is also set."
  }
}

run "rejects_arm_instance_type" {
  command = plan

  variables {
    instance_type = "t4g.micro"
  }

  override_data {
    target = data.aws_ec2_instance_type.this
    values = {
      supported_architectures         = ["arm64"]
      burstable_performance_supported = true
    }
  }

  expect_failures = [aws_instance.this]
}

run "rejects_same_ports" {
  command = plan

  variables {
    api_port  = 9000
    keys_port = 9000
  }

  expect_failures = [aws_instance.this]
}

run "rejects_bad_inputs" {
  command = plan

  variables {
    name                   = "1-bad name"
    api_port               = 70000
    management_cidr_blocks = ["not-a-cidr"]
  }

  expect_failures = [
    var.name,
    var.api_port,
    var.management_cidr_blocks,
  ]
}
