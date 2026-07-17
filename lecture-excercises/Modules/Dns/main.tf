resource "dns_a_record_set" "helloRecord" {
  zone = "${var.dns_zone}." # The dot matters!
  name = var.server_name
  addresses = var.server_ip
  ttl = 10
}

resource "dns_a_record_set" "alias" {
  for_each  = toset(distinct(var.server_aliases))
  zone      = "${var.dns_zone}."  # The dot matters!
  name      = each.value
  addresses = var.server_ip
  ttl       = 10
}
