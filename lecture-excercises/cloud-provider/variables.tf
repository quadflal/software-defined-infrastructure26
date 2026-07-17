variable "hcloud_token" {
  nullable  = false
  sensitive = true
}

variable "ssh_public_keys" {
  type = map(string)
}

variable "dnsZone" {
  type     = string
  nullable = false
}

variable "serverBaseName" {
  type     = string
  nullable = false
}

variable "serverCount" {
  type     = number
  nullable = false

  validation {
    condition     = var.serverCount >= 1 && floor(var.serverCount) == var.serverCount
    error_message = "serverCount must be a positive integer."
  }
}

variable "dns_secret" {
  type      = string
  nullable  = false
  sensitive = true
}
