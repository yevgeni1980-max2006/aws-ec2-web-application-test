
variable "db_password" {
  description = "MySQL root password"
  type        = string
  default     = "SuperSecret123!"
}

variable "db_username" {
  description = "WordPress MySQL user"
  type        = string
  default     = "wordpress_user"
}

variable "db_name" {
  description = "WordPress database name"
  type        = string
  default     = "wordpress"
}

variable "domain_name" {
  description = "Public domain name for WordPress (e.g., example.com)"
  type        = string
}
