terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "7.28.0"
    }
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = "0.16.0"
    }
  }

   backend "s3" {
    bucket                      = "homelab-terraform-state"
    key                         = "vps/terraform.tfstate"
    region                      = "auto" # R2 requires this to be set to "auto"
    endpoint                    = var.s3_endpoint
    
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

provider oci {
	region = var.region
	tenancy_ocid = data.bitwarden_secret.tenancy_ocid.value
	user_ocid = data.bitwarden_secret.user_ocid.value
	private_key = data.bitwarden_secret.oci_private_key.value
	fingerprint = data.bitwarden_secret.oci_fingerprint.value
}
