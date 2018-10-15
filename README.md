# TerraformOutlineVPN
Terraform scripts to create a quick Outline VPN server (https://getoutline.org) in the cloud (AWS, Google (GCP), more to come). Can be trivially modified to work with other cloud providers.

## Steps for use

1. [Download Terraform](https://www.terraform.io/downloads.html).
2. For AWS, be sure your AWS profile is setup (i.e., `$HOME/.aws/config`).
3. For GCP, be sure to generate your `account.json` from [Google Application Default Credentials](https://developers.google.com/identity/protocols/application-default-credentials) or, more easily, simply login with `gcloud auth application-default login`.
4. For Azure, be sure you have the Azure CLI installed and complete an `az login`
5. Create your SSH keys:

    `cd TerraformOutlineVPN`

    `ssh-keygen -N '' -f ./certs/outline`

6. In the cloud provider you're using, edit the region in `variables.tf` as needed (default is Canada).
7. For GCP, be sure you've created a new project and noted it in `variables.tf`.
8. cd to the cloud provider directory and perform a `terraform apply`.

## To Do

- Finish client installation instructions
- Better use of variables and file hierarchy to allow for a single variables file and one place to execute the `apply` command.
- Enable this repository to be used as a module.
- Fix Azure implementation to use API/metadata to retrieve external IP.
