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

variable "dns_secret" {
  type      = string
  nullable  = false
  sensitive = true
}
