# TerraformOutlineVPN

Terraform for running your own [Outline VPN](https://getoutline.org) server on AWS. One `terraform apply` gives you an Amazon Linux 2023 instance with a fixed Elastic IP, a security group that opens only the ports Outline uses, and the official Outline server installed and ready to connect to Outline Manager.

I first wrote this in 2018 for Terraform 0.11. It has since been rewritten for current Terraform and AWS provider releases; see [CHANGELOG.md](CHANGELOG.md) for what changed.

## How it works

1. Terraform allocates an Elastic IP first, so the server's public address is known before it boots. Outline puts that address into every access key, so it never changes.
2. It picks two ports at random (or uses the ones you set): one for the management API and one for access keys. The security group allows only those two ports, plus SSH if you ask for it.
3. On first boot the instance installs Docker and runs Outline's own `install_server.sh`, pinned to a specific commit, with that hostname and those ports.
4. When the install finishes, the instance writes the Outline Manager config (`apiUrl` and `certSha256`) to an SSM Parameter Store `SecureString`. You fetch it with one AWS CLI command and paste it into Outline Manager.

The server has no SSH key and no open SSH port by default. If you need a shell, use AWS Systems Manager Session Manager. The management secret never touches Terraform state; it lives on the instance and in the encrypted SSM parameter.

## Requirements

- [Terraform](https://developer.hashicorp.com/terraform/install) 1.5 or newer, or [OpenTofu](https://opentofu.org/docs/intro/install/) 1.6 or newer
- An AWS account, with credentials available to Terraform (`AWS_PROFILE`, `aws sso login`, environment variables, and so on)
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), to fetch the Outline Manager config
- [Outline Manager](https://getoutline.org/get-started/#step-1) on your computer and an [Outline client](https://getoutline.org/get-started/#step-3) on each device that will connect
- Optional: the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) for the AWS CLI, if you want a shell on the server

## Quick start

```sh
git clone https://github.com/gudlyf/TerraformOutlineVPN.git
cd TerraformOutlineVPN/AWS

cp terraform.tfvars.example terraform.tfvars   # then edit: region, your IP, etc.

terraform init
terraform apply
```

The apply takes a minute or two. The instance then needs about 3 to 5 more minutes to install Docker and Outline. When it's done, run the command Terraform printed:

```sh
$(terraform output -raw manager_config_command)
```

It prints a line like this:

```json
{"apiUrl":"https://203.0.113.10:12345/AbCdEf...","certSha256":"9F2C..."}
```

In Outline Manager, add a server, choose the option to set up Outline anywhere, and paste that line into step 2. From there you create access keys in Manager and share them with your devices.

If the command fails with `ParameterNotFound`, the install hasn't finished yet. Give it another minute, or see [Troubleshooting](#troubleshooting).

## Configuration

Everything is optional. Set values in `AWS/terraform.tfvars`.

| Variable | Default | What it does |
|---|---|---|
| `region` | `ca-central-1` | AWS region to run the server in |
| `name` | `outline` | Name tag and prefix for every resource |
| `server_name` | `Outline (<region>)` | Name Outline Manager shows for the server. Changing it later rebuilds the server (rename it in Manager instead) |
| `instance_type` | `t3.micro` | EC2 instance type. Must be x86_64 (see below) |
| `subnet_id` | `null` | Use an existing public subnet instead of creating a VPC |
| `api_port` | random 1024-16383 | Management API port (TCP). Changing it later rebuilds the server |
| `keys_port` | random 16384-32767 | Access-key port (TCP and UDP). `443` is a common choice on networks that block odd ports. Changing it later rebuilds the server |
| `management_cidr_blocks` | `["0.0.0.0/0"]` | Who can reach the management API. Set this to your own `/32` if your IP is stable |
| `access_cidr_blocks` | `["0.0.0.0/0"]` | Who can use the VPN |
| `enable_ssm_session_manager` | `true` | Allow shell access through Session Manager |
| `ssh_key_name` | `null` | Existing EC2 key pair, if you want SSH |
| `ssh_cidr_blocks` | `[]` | Where SSH is allowed from. SSH stays closed unless both this and `ssh_key_name` are set |
| `tags` | `{}` | Extra tags for every resource |

The module has a few more inputs (custom AMI, root volume size, CPU credit mode, VPC CIDR, which Outline installer commit to use). They're listed in [modules/outline-aws/README.md](modules/outline-aws/README.md).

Why x86_64 only? The official Outline server image (`quay.io/outline/shadowbox`) is published for amd64 only, so Graviton (`t4g`, `m7g` and so on) instances won't run it. The module checks this at plan time.

### Using it as a module

The `AWS/` directory is a thin wrapper around `modules/outline-aws`. You can call the module from your own configuration instead:

```hcl
module "outline" {
  source = "github.com/gudlyf/TerraformOutlineVPN//modules/outline-aws?ref=master"

  name                   = "outline-tor"
  management_cidr_blocks = ["203.0.113.25/32"]
}

output "outline_manager_config_command" {
  value = module.outline.manager_config_command
}
```

Pin `ref` to a tag or commit rather than `master` for anything you care about. To run servers in several regions, call the module once per region with an aliased `aws` provider.

## Day-to-day operation

### Getting a shell

`$(terraform output -raw session_manager_command)` opens a shell through Session Manager as `ssm-user`, which has `sudo`. The bootstrap log is `/var/log/cloud-init-output.log`, and Outline's own state is under `/opt/outline`.

### Updates

The Outline installer also starts Watchtower, which checks for a new Outline server image every hour and restarts the container when it finds one. You don't need to do anything for Outline itself.

The OS is different. Amazon Linux 2023 locks each instance to the release it launched with, and Terraform deliberately ignores newer AMIs (a new AMI would replace the instance and throw away every access key). To patch in place, open a shell, run `sudo dnf upgrade --releasever=latest`, then reboot.

### Settings that rebuild the server

`api_port`, `keys_port`, `server_name` and the installer version are baked into the first-boot script. Changing any of them after the first apply replaces the instance, and Terraform's plan will say `must be replaced`. The Elastic IP stays the same, but the new server has a new management secret and certificate, so you'll add it to Outline Manager again and hand out new keys. Pick your ports before the first apply if you care what they are.

The CIDR variables (`management_cidr_blocks`, `access_cidr_blocks`, `ssh_cidr_blocks`) only touch the security group and are safe to change any time.

### Changing the port in Outline Manager

Outline Manager lets you change the port for new access keys. The security group won't know about it, and setting `keys_port` to match would rebuild the server. Instead, add a rule for the new port (TCP and UDP) to the security group yourself. `terraform output security_group_id` gives you its ID.

### Tearing down

`terraform destroy` removes everything Terraform created. The SSM parameter is written by the instance, not by Terraform, so remove it yourself if you're done for good:

```sh
aws ssm delete-parameter --region <region> --name /outline/outline-manager-config
```

## Costs

You pay for one `t3.micro` instance, its public IPv4 address (AWS bills for every public IPv4 address, Elastic or not), a 10 GiB gp3 volume and outbound data transfer. Check the [EC2 pricing page](https://aws.amazon.com/ec2/pricing/on-demand/) for your region. Burstable instances default to `standard` CPU credits, so a busy server slows down instead of running up an `unlimited` credit bill.

## Security notes

- Only the management API port and the access-key port are open by default. The management API also requires a random secret in its URL and a pinned self-signed certificate, but restricting `management_cidr_blocks` to your own IP is still worth doing if you can.
- The instance requires IMDSv2 and has an encrypted root volume.
- Its IAM role can write one SSM parameter and, if Session Manager is on, use the `AmazonSSMManagedInstanceCore` managed policy.
- The installer's output, which includes the management secret, goes to `/root/outline-install.log` (root only) instead of the cloud-init log, so it doesn't show up in the EC2 console output.
- Terraform state holds no Outline secrets, but it does contain your account ID, IP address and resource IDs. Keep it somewhere private, or set up the S3 backend shown in `AWS/versions.tf`.

To report a security problem with this repository, see [SECURITY.md](SECURITY.md).

## Troubleshooting

### `ParameterNotFound` when fetching the Manager config

The install takes a few minutes after `apply` returns. If it's been more than ten, open a Session Manager shell and check `/var/log/cloud-init-output.log`. Lines from this repo's bootstrap start with `==> [outline-bootstrap]`. The installer's own stdout is in `/root/outline-install.log`.

### Session Manager says the target isn't connected

The SSM agent needs a minute or two after boot to register. Also make sure the Session Manager plugin is installed locally.

### Outline Manager can't reach the server

Check that your current IP is inside `management_cidr_blocks`. Home IPs change.

### Clients can't connect

Check that `access_cidr_blocks` includes the client's network and that the key's port matches `keys_port` (or a rule you added yourself).

## Upgrading from the old (Terraform 0.12) version

The old layout can't be upgraded in place. It used a different resource layout, a default-VPC security group, an SSH key from `certs/` and the long-dead `template` provider. The simplest path:

1. Destroy the old server, either with the Terraform version you originally used or by hand in the AWS console: the `outline-server` instance, the `outline_sg` security group, the `outline-server_ec2_role` IAM role and instance profile, and the `outline-key-*` key pair.
2. Delete your old `terraform.tfstate` files.
3. Follow the quick start above. Existing access keys don't carry over, so you'll hand out new ones.

## Repository layout

```
AWS/                       Deployable configuration (run terraform here)
modules/outline-aws/       Reusable module: VPC, security group, IAM, EC2, Elastic IP
  templates/               First-boot script (rendered with templatefile)
  tests/                   terraform test suite (mocked, no AWS needed)
.github/workflows/ci.yml   fmt, validate, test, tflint and shellcheck on every PR
```

## Contributing

Pull requests are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) covers the local checks and a few conventions worth knowing before you change the module.

## License

[MIT](LICENSE)
