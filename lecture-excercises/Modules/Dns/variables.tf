variable "dns_zone" {
  type     = string
  nullable = false
}

variable "server_addresses" {
  type     = map(string)
  nullable = false

  validation {
    condition = alltrue([
      for name, address in var.server_addresses :
      name != "" && !strcontains(name, ".") && can(cidrnetmask("${address}/32"))
    ])
    error_message = "server_addresses must map non-empty DNS labels without dots to valid IPv4 addresses."
  }
}

variable "dns_secret" {
  type      = string
  nullable  = false
  sensitive = true
}
