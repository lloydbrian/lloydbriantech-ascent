terraform {
  required_version = "~> 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.13.0"
}

module "tags" {
  source = "git::https://github.com/example/tags.git?ref=v1.2.0"
}

module "local" {
  source = "./modules/local"
}
