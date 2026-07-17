variable "hcloud_token" {
  nullable  = false
  sensitive = true
}
variable "ssh_public_keys" {
  type = map(string)
}

variable "dns_zone" {
  type     = string
  nullable = false
}

variable "server_names" {
  type     = list(string)
  nullable = false
}

variable "dns_secret" {
  type      = string
  nullable  = false
  sensitive = true
}
