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

variable "server_name" {
  type     = string
  nullable = false
}

variable "server_aliases" {
  type     = list(string)
  nullable = false

  validation {
    condition = !contains(var.server_aliases, var.server_name)
    error_message = "The server_aliases must not contain the server_name. Please remove it from the list."
  }
}

variable "dns_secret" {
  type      = string
  nullable  = false
  sensitive = true
}
