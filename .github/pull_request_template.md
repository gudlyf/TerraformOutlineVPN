## What and why

<!-- What does this change, and what problem does it solve? Link the issue if there is one. -->

## Checks

- [ ] `terraform fmt -recursive`, `terraform validate` and `terraform test` pass
- [ ] TFLint and ShellCheck pass
- [ ] Module README and root README updated for any new or changed variables
- [ ] Line added under `Unreleased` in CHANGELOG.md
- [ ] Deployed to real AWS and connected a client (needed for changes to the first-boot script or security group). Region and instance type:
