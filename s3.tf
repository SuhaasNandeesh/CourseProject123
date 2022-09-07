terraform {
  backend "s3" {
    bucket         = "suhaasnandeesh-tf-backend"
    key            = "env/dev"
    region         = "us-east-1"
    dynamodb_table = "tf-state-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}