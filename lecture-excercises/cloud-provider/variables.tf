variable "hcloud_token" {
  nullable  = false
  sensitive = true
}
variable "ssh_public_keys" {
  type = map(string)
}