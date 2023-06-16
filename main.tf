terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }
  required_version = ">= 1.5.0"

  cloud {
    organization = "john-carmack"

    workspaces {
      name = "migrate-to-s3-deep-storage-for-business"
    }
  }
}
