variable "ssh_public_keys" {
  type = map(string)
}

variable "private_subnet" {
  type = object({
    dnsDomainName = string
    ipAndNetmask  = string
  })

  validation {
    condition     = can(cidrhost(var.private_subnet.ipAndNetmask, 3))
    error_message = "private_subnet.ipAndNetmask must be a valid subnet with at least four addresses."
  }
}

variable "network_ip_range" {
  type    = string
  default = "10.0.0.0/16"
}

variable "location" {
  type    = string
  default = "nbg1"
}

variable "network_zone" {
  type    = string
  default = "eu-central"
}
