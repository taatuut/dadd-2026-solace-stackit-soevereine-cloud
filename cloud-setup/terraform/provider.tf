terraform {
  required_version = ">= 1.5"

  required_providers {
    solacecloud = {
      source = "solaceproducts/solacecloud"
      # BETA provider -- pin to the exact version shown by `terraform init`
      # the first time you run it (check
      # https://registry.terraform.io/providers/SolaceProducts/solacecloud/latest
      # for the current release). Deliberately unpinned here so the first
      # `terraform init` tells you what's actually current.
    }
  }
}

# Two separate Solace Cloud organizations are involved (see this folder's
# README.md and ../../PLAN.md section 13, point 40): AWS + Azure live in
# one org, STACKIT in another. Each org has its own API token AND its own
# Home Cloud base_url -- do not assume both orgs use the same base_url.
provider "solacecloud" {
  alias     = "aws_azure_org"
  base_url  = var.aws_azure_org_base_url
  api_token = var.aws_azure_org_api_token
}

provider "solacecloud" {
  alias     = "stackit_org"
  base_url  = var.stackit_org_base_url
  api_token = var.stackit_org_api_token
}
