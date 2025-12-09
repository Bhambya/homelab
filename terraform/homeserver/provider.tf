terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.89.1"
    }
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = "0.16.0"
    }
  }

  backend "s3" {
    bucket   = "homelab-terraform-state"
    key      = "homeserver/terraform.tfstate"
    region   = "auto" # R2 requires this to be set to "auto"
    endpoint = var.s3_endpoint

    # Credentials will be passed via environment variables
    # access_key =  # env variable AWS_ACCESS_KEY_ID (get from BW secret a6f69723-99c3-40d1-9888-b39000ca1867)
    # secret_key =  # env variable AWS_SECRET_ACCESS_KEY (get from BW secret c9e13db6-5c78-4c62-8110-b39000ca3ea3)

    # Required settings for S3-compatible (non-AWS) providers
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }
}

provider "bitwarden" {
  access_token = var.bw_access_token
  experimental {
    embedded_client = true
  }
}

# Configure the Proxmox provider
provider "proxmox" {
  endpoint = var.proxmox_api_url

  api_token = var.proxmox_api_token_secret

  # because self-signed TLS certificate is in use
  insecure = true
  # uncomment (unless on Windows...)
  tmp_dir = "/var/tmp"

  ssh {
    agent = true
    username = "root"
  }
}
