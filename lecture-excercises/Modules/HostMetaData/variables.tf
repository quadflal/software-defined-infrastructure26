variable "ssh_public_keys" {
  type = map(string)
}

variable "name" {
  type = string
  nullable = false
}

variable "hcloud_token" {
  type = string
  nullable = false
}