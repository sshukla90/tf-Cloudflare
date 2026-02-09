# Cloudflare Infrastructure Management
# This is the root configuration that orchestrates all modules

# Security Module - IP Access Rules
module "security" {
  source = "./security"
  
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_zone_id    = var.cloudflare_zone_id
  config_file_path      = var.config_file_path
}

# Future modules can be added here:
# 
# module "dns" {
#   source = "./dns"
#   cloudflare_zone_id = var.cloudflare_zone_id
# }
#
# module "waf" {
#   source = "./waf"
#   cloudflare_zone_id = var.cloudflare_zone_id
# }
#
# module "workers" {
#   source = "./workers"
#   cloudflare_account_id = var.cloudflare_account_id
# }
