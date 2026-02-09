variable "cloudflare_account_id" {
  description = "Cloudflare Account ID for account-level rules"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for zone-level rules"
  type        = string
}

variable "config_file_path" {
  description = "Path to the YAML configuration file"
  type        = string
}
