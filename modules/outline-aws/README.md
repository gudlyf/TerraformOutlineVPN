# outline-aws

Terraform module that runs an [Outline VPN](https://getoutline.org) server on a single Amazon Linux 2023 EC2 instance. See the [repository README](../../README.md) for the walkthrough; this page is the reference.

```hcl
module "outline" {
  source = "github.com/gudlyf/TerraformOutlineVPN//modules/outline-aws?ref=master"

  name                   = "outline"
  management_cidr_blocks = ["203.0.113.25/32"]
}
```

The module has no provider block. It deploys into whatever region the calling configuration's `aws` provider uses.

## What it creates

- A VPC, internet gateway, public subnet and route table (skipped when you pass `subnet_id`)
- A security group with ingress for the management API port (TCP), the access-key port (TCP and UDP) and, optionally, SSH
- An IAM role and instance profile that can write one SSM parameter, plus `AmazonSSMManagedInstanceCore` when Session Manager is on
- An Elastic IP and its association
- The EC2 instance (IMDSv2 required, encrypted gp3 root volume)
- Two `random_integer` resources for the default ports

The instance itself creates one more thing: an SSM `SecureString` parameter holding the Outline Manager config. Terraform doesn't manage it, so `terraform destroy` leaves it behind.

## Requirements

| Name | Version |
|---|---|
| terraform / opentofu | >= 1.5.0 / >= 1.6.0 |
| hashicorp/aws | >= 6.0.0, < 7.0.0 |
| hashicorp/random | >= 3.6.0, < 4.0.0 |

Running the tests in `tests/` needs Terraform 1.7+ or OpenTofu 1.8+.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `"outline"` | Name tag and prefix for all resources. Letters, digits and hyphens, starting with a letter, max 31 characters. |
| `server_name` | `string` | `null` | Display name in Outline Manager. Defaults to `Outline (<region>)`. |
| `instance_type` | `string` | `"t3.micro"` | Must support x86_64. Checked at plan time. |
| `ami_id` | `string` | `null` | AMI override. Defaults to the latest Amazon Linux 2023 x86_64 AMI. The first-boot script assumes AL2023. |
| `root_volume_size` | `number` | `10` | Root volume size in GiB (minimum 8). |
| `burstable_cpu_credits` | `string` | `"standard"` | `standard` or `unlimited`. Only applies to T-family instances. |
| `subnet_id` | `string` | `null` | Existing public subnet. Must route `0.0.0.0/0` to an internet gateway. When null, a dedicated VPC is created. |
| `vpc_cidr` | `string` | `"10.42.0.0/24"` | CIDR for the dedicated VPC and its single subnet. |
| `api_port` | `number` | `null` | Management API port. Null picks a random port in 1024-16383 once and keeps it. |
| `keys_port` | `number` | `null` | Access-key port (TCP and UDP). Null picks a random port in 16384-32767 once and keeps it. |
| `management_cidr_blocks` | `list(string)` | `["0.0.0.0/0"]` | IPv4 CIDRs allowed to reach the management API. |
| `access_cidr_blocks` | `list(string)` | `["0.0.0.0/0"]` | IPv4 CIDRs allowed to reach the access-key port. |
| `enable_ssm_session_manager` | `bool` | `true` | Attach `AmazonSSMManagedInstanceCore` for Session Manager shells. |
| `ssh_key_name` | `string` | `null` | Existing EC2 key pair. SSH is only enabled when this and `ssh_cidr_blocks` are both set. |
| `ssh_cidr_blocks` | `list(string)` | `[]` | IPv4 CIDRs allowed to reach port 22. |
| `install_script_ref` | `string` | pinned commit SHA | Git ref of `OutlineFoundation/outline-server` whose `install_server.sh` runs on first boot. |
| `manager_config_parameter_name` | `string` | `null` | SSM parameter for the Manager config. Defaults to `/<name>/outline-manager-config`. |
| `tags` | `map(string)` | `{}` | Tags for every resource. |

## Outputs

| Name | Description |
|---|---|
| `instance_id` | EC2 instance ID |
| `public_ip` | Elastic IP. Access keys point here. |
| `api_port` | Management API port |
| `keys_port` | Access-key port |
| `security_group_id` | Security group ID |
| `vpc_id` | VPC ID (created or looked up from `subnet_id`) |
| `subnet_id` | Subnet ID |
| `manager_config_parameter_name` | SSM parameter the instance writes the Manager config to |
| `manager_config_command` | AWS CLI command that prints the Manager config JSON |
| `session_manager_command` | AWS CLI command for a Session Manager shell, or null when disabled |

## Behavior worth knowing

Changing anything in the first-boot script replaces the instance. That covers the ports, the Elastic IP, the server name and `install_script_ref`. A replaced server has a new management secret and certificate, so you'll have to re-add it in Outline Manager and issue new keys.

A newer AMI doesn't replace the instance, because `ami` is in `ignore_changes`. Patch in place with `sudo dnf upgrade --releasever=latest`.

The instance launches without a public IP and waits up to ten minutes for the Elastic IP to be attached before it installs anything. (`associate_public_ip_address` is also in `ignore_changes`, since the provider reads it back as `true` after the Elastic IP attaches and would otherwise replace the server on the next apply.) With `subnet_id`, the subnet must be public, with a route to an internet gateway. A NAT-only subnet won't work, because the Elastic IP is also the server's public address.

Only IPv4 is opened inbound. Access keys use the Elastic IP, so clients always connect over IPv4.

The installer's stdout, which includes the management secret, goes to `/root/outline-install.log` instead of the cloud-init log.
