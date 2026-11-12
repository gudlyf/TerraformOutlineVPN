terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State is kept locally by default. To share it or keep it off your laptop,
  # configure a remote backend here, for example:
  #
  # backend "s3" {
  #   bucket       = "my-terraform-state"
  #   key          = "outline-vpn/terraform.tfstate"
  #   region       = "ca-central-1"
  #   use_lockfile = true
  # }
}
