variable "hcloud_token" {
  type      = string
  nullable  = false
  sensitive = true
}

variable "server_ip" {
  type     = string
  nullable = false
}

variable "dns_zone" {
  type     = string
  nullable = false
}

variable "server_names" {
  type     = list(string)
  nullable = false

  validation {
    condition     = alltrue([for name in var.server_names : name != "" && !strcontains(name, ".")])
    error_message = "The server_names must contain non-empty DNS labels without dots."
  }
}

variable "dns_secret" {
  type      = string
  nullable  = false
  sensitive = true
}
