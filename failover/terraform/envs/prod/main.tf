terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  # Recommended in prod: Configure remote state with locking
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "k3s-failover/prod/terraform.tfstate"
  #   region         = "ap-southeast-3"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

locals {
  environment = "prod"

  user_data_rendered = templatefile("${path.module}/../../bootstrap/cloud-init.yaml.tpl", {
    environment                = local.environment
    k3s_version                = var.k3s_version
    b2_endpoint                = var.b2_endpoint
    b2_bucket                  = var.b2_bucket
    b2_key_id                  = var.b2_key_id
    b2_application_key         = var.b2_application_key
    b2_prefix                  = var.b2_prefix
    gitops_repo_url            = var.gitops_repo_url
    gitops_branch              = var.gitops_branch
    restore_script_content     = indent(4, file("${path.module}/../../bootstrap/restore.sh"))
    healthcheck_script_content = indent(4, file("${path.module}/../../bootstrap/healthcheck.sh"))
  })
}

module "network" {
  source = "../../modules/network"

  project_name      = var.project_name
  environment       = local.environment
  vpc_cidr          = var.vpc_cidr
  subnet_cidr       = var.subnet_cidr
  availability_zone = "${var.aws_region}a"
  tags              = var.tags
}

module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = local.environment
  tags         = var.tags
}

module "compute" {
  source = "../../modules/compute"

  project_name             = var.project_name
  environment              = local.environment
  vpc_id                   = module.network.vpc_id
  subnet_id                = module.network.subnet_id
  instance_type            = var.instance_type
  ami_architecture         = var.ami_architecture
  iam_instance_profile     = module.iam.instance_profile_name
  key_name                 = var.key_name
  user_data_base64         = base64encode(local.user_data_rendered)
  root_volume_size         = var.root_volume_size
  allocate_eip             = var.allocate_eip
  allowed_http_cidr_blocks = var.allowed_http_cidr_blocks
  allowed_ssh_cidr_blocks  = var.allowed_ssh_cidr_blocks
  allowed_k3s_cidr_blocks  = var.allowed_k3s_cidr_blocks
  tags                     = var.tags
}

module "dns" {
  source = "../../modules/dns"

  environment        = local.environment
  dns_provider       = var.dns_provider
  enable_dns_switch  = var.enable_dns_switch
  record_name        = var.prod_record_name
  target_ip          = module.compute.public_ip
  cloudflare_zone_id = var.cloudflare_zone_id
  route53_zone_id    = var.route53_zone_id
}
