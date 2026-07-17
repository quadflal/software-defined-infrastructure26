# Task 22 - Creating DNS records

1. Start from scratch: Remove resources from previous exercises and create a minimal configuration containing just an
   »A« record.

Solution:

``` java

resource "dns_a_record_set" "helloRecord" {
  zone = "${var.dns_zone}." # The dot matters!
  name = var.server_name
  addresses = var.server_ip
  ttl = 10
}

```

2. Add the two aliases.

Solution:

``` java
   
resource "dns_a_record_set" "alias" {
  for_each  = toset(distinct(var.server_aliases))
  zone      = "${var.dns_zone}."  # The dot matters!
  name      = each.value
  addresses = var.server_ip
  ttl       = 10 }

```

3. Define corresponding variables and re-factor any hard coded strings accordingly e.g.:

``` text

# config.auto.tfvars
server_ip      = "1.2.3.4"
dns_zone       = "gxy.sdi.hdm-stuttgart.cloud"
server_name    = "workhorse"
server_aliases = ["www", "mail"]

```

Solution:

``` hcl

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

```
4. Your configuration may be prone to two different types of configuration errors: 
   - Duplicate server alias names
   - Server alias name matching server's common name

Solution: 

``` hcl

variable "server_aliases" {
  type     = list(string)
  nullable = false

  validation {
    condition = !contains(var.server_aliases, var.server_name)
    error_message = "The server_aliases must not contain the server_name. Please remove it from the list."
  }
}
```