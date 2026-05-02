terraform {
  required_version = ">= 1.5"

  required_providers {
    akp = {
      source  = "akuity/akp"
      version = "~> 0.10"
    }
  }
}

# Auth: set AKUITY_API_KEY_ID and AKUITY_API_KEY_SECRET env vars
provider "akp" {
  org_name = var.org_name
}
