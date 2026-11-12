# Changelog

Notable changes to this project. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

A full rewrite for current Terraform and AWS. Existing deployments can't be upgraded in place; see "Upgrading from the old version" in the README.

### Added

- Reusable module at `modules/outline-aws`. `AWS/` is now a thin root configuration that calls it.
- A dedicated VPC and public subnet by default, or bring your own with `subnet_id`.
- An Elastic IP allocated before boot, so access keys always point at a stable address.
- Fixed management and access-key ports (random by default, or set `api_port` and `keys_port`). The security group opens only those ports.
- The Outline Manager config is published to an SSM Parameter Store `SecureString`, and a `manager_config_command` output fetches it.
- Session Manager access through `AmazonSSMManagedInstanceCore`. SSH is now optional and closed by default.
- Input validation, plan-time checks for x86_64 instance types and distinct ports, and a `terraform test` suite that runs on mocked providers.
- GitHub Actions CI (fmt, validate, test on Terraform and OpenTofu, TFLint, ShellCheck), Dependabot, pre-commit config, CONTRIBUTING and SECURITY docs.
- A committed provider lock file for `AWS/`.
- MIT license.

### Changed

- Requires Terraform 1.5+ (or OpenTofu 1.6+) and AWS provider 6.x.
- Amazon Linux 2 (end of life) replaced by Amazon Linux 2023, looked up through the public SSM parameter.
- Runs the current upstream installer from `OutlineFoundation/outline-server`, pinned to a commit with `install_script_ref`.
- Default instance type is `t3.micro`, with `standard` CPU credits.
- `associate_public_ip_address` is ignored after creation so the attached Elastic IP doesn't force a replacement.
- IMDSv2 required, encrypted gp3 root volume, IAM names use prefixes so several servers can share an account.
- `template_file` (from the archived `template` provider) replaced with `templatefile()`.
- `terraform.tfvars` is no longer committed; copy `AWS/terraform.tfvars.example`.

### Removed

- SSH provisioners, `scp` of the install output (the installer's output, including the management secret, now goes to a root-only file on the instance) and the `certs/` and `client_configs/` directories.
- The `ec2:AuthorizeSecurityGroupIngress` instance permission, which nothing used.
- The `1024-65535` TCP/UDP ingress range, the open SSH port and the IPv6 (`::/0`) ingress rules. Access keys use the IPv4 Elastic IP, so inbound IPv6 wasn't doing anything.
- The `profile` variable. Use `AWS_PROFILE` or any other standard credential source.
- Overriding the instance's DNS resolvers to 1.1.1.1 and 9.9.9.9. The instance uses the VPC resolver.
- References to GCP and Azure support, which never existed in this repository.

## 2019-11-26

- Upgraded to Terraform 0.12 syntax.

## 2018-10-15

- Initial AWS version: Amazon Linux 2 on `t2.nano`, SSH-based provisioning, IPv4 and IPv6 security group rules.
