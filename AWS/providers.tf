# Credentials come from the standard AWS chain: AWS_PROFILE, environment
# variables, SSO, or an instance/role profile.
provider "aws" {
  region = var.region

  default_tags {
    tags = merge(
      {
        Project   = "outline-vpn"
        ManagedBy = "terraform"
      },
      var.tags,
    )
  }
}
