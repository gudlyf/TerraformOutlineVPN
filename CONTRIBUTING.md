# Contributing

Thanks for taking a look. Bug reports, fixes and small features are all welcome. For anything bigger, such as another cloud provider or a change to how the server is bootstrapped, open an issue first so we can agree on the approach before you spend time on it.

## Setting up

You'll need:

- Terraform 1.7+ (for `terraform test`) or OpenTofu 1.8+
- [TFLint](https://github.com/terraform-linters/tflint)
- [ShellCheck](https://www.shellcheck.net/)
- Optional: [pre-commit](https://pre-commit.com/), then `pre-commit install` to run fmt, validate and TFLint on each commit

None of the checks below need AWS credentials.

## Checks to run before opening a PR

CI runs all of these, but it's faster to catch problems locally:

```sh
terraform fmt -recursive

(cd AWS && terraform init -backend=false && terraform validate)

cd modules/outline-aws
terraform init -backend=false
terraform validate
terraform test
cd ../..

tflint --init
tflint --recursive --config "$PWD/.tflint.hcl"

shellcheck --shell=bash modules/outline-aws/templates/user_data.sh.tftpl
```

The tests in `modules/outline-aws/tests/` use mocked providers, so they run offline and create nothing. If you add a variable or change a behavior, add or update a `run` block that covers it.

## Testing against real AWS

If your change touches the first-boot script, the security group or anything else that only shows up on a live server, please deploy it once before asking for review:

1. `cd AWS && terraform apply` in a throwaway account or region.
2. Wait for `$(terraform output -raw manager_config_command)` to return the JSON.
3. Add the server in Outline Manager, create a key, and connect from a client.
4. `terraform destroy`, and delete the SSM parameter.

A test run costs a few cents. Mention in the PR that you did this, and which region and instance type you used.

## Conventions

### The first-boot script is a Terraform template

`templates/user_data.sh.tftpl` is rendered with `templatefile()`, so `${...}` means a Terraform value. Write shell variables as `$name` without braces. If you really need a literal `${` in the script, including in a comment, escape it as `$${`.

### Validate inputs

New variables need a `type`, a `description`, and a `validation` block wherever bad input would otherwise fail late in AWS.

### Document variables in two places

When you add or change a module variable, update the table in `modules/outline-aws/README.md`. If it's something most people would set, also pass it through `AWS/variables.tf` and `AWS/main.tf` and list it in the root README.

### Lock files

`AWS/.terraform.lock.hcl` is committed. If you change provider constraints, regenerate it for all platforms:

```sh
cd AWS
terraform providers lock -platform=linux_amd64 -platform=linux_arm64 \
  -platform=darwin_amd64 -platform=darwin_arm64 -platform=windows_amd64
```

The module directory has no committed lock file; callers lock their own providers.

### Bumping the Outline installer

`install_script_ref` is pinned to a commit in `OutlineFoundation/outline-server`. To move it, read the diff of `src/server_manager/install_scripts/install_server.sh` between the old and new commits, then do a real-AWS test. Changing the default replaces existing servers on their next apply, so call that out in `CHANGELOG.md`.

## Pull requests

- Keep each PR to one change, and explain why as well as what.
- Add a line under `Unreleased` in `CHANGELOG.md`.
- Never commit `terraform.tfvars`, state files or anything with real account IDs or IPs. `.gitignore` covers the usual suspects.

## Reporting bugs

Open an issue with your Terraform or OpenTofu version, the AWS provider version from `terraform version`, your region and instance type, and what you saw. If the server was created but Outline isn't working, the bootstrap lines from `/var/log/cloud-init-output.log` (the ones starting `==> [outline-bootstrap]`) help a lot. Please remove IPs and `apiUrl` values first.

Problems with Outline itself, such as the server software, Manager or clients, belong upstream at [OutlineFoundation](https://github.com/OutlineFoundation).
