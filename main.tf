resource "random_id" "this" {
  keepers     = { name = var.name }
  byte_length = 8
}

resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = var.name
  resource_group_name = var.rg.name
  sku_name            = var.profile_sku_name
}

resource "azurerm_cdn_frontdoor_endpoint" "this" {
  name                     = substr("${var.name}${random_id.this.dec}", 0, 24)
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
}

resource "azurerm_cdn_frontdoor_origin_group" "this" {
  name                     = var.name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  session_affinity_enabled = var.origin_group.session_affinity_enabled

  load_balancing {
    sample_size                 = var.origin_group.load_balancing.sample_size
    successful_samples_required = var.origin_group.load_balancing.successful_samples_required
  }

  health_probe {
    path                = var.origin_group.health_probe.path
    request_type        = var.origin_group.health_probe.request_type
    protocol            = var.origin_group.health_probe.protocol
    interval_in_seconds = var.origin_group.health_probe.interval_in_seconds
  }
}

resource "azurerm_cdn_frontdoor_origin" "this" {
  for_each                       = var.origins
  name                           = "${var.name}-${each.key}"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.this.id
  enabled                        = each.value.enabled
  host_name                      = each.value.host_name
  http_port                      = each.value.http_port
  https_port                     = each.value.https_port
  origin_host_header             = coalesce(each.value.original_host_header, each.value.host_name)
  priority                       = each.value.priority
  weight                         = each.value.weight
  certificate_name_check_enabled = each.value.certificate_name_check_enabled
}

resource "azurerm_cdn_frontdoor_route" "this" {
  for_each                        = var.routes
  name                            = "${var.name}-${each.key}"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.this.id
  cdn_frontdoor_origin_ids        = [for k, v in azurerm_cdn_frontdoor_origin.this : v.id]
  cdn_frontdoor_custom_domain_ids = [for k, v in azurerm_cdn_frontdoor_custom_domain.this : v.id]

  supported_protocols    = each.value.supported_protocols
  patterns_to_match      = each.value.patterns_to_match
  forwarding_protocol    = each.value.forwarding_protocol
  link_to_default_domain = each.value.link_to_default_domain
  https_redirect_enabled = each.value.https_redirect_enabled

  cache {
    query_string_caching_behavior = each.value.cache.query_string_caching_behavior
    query_strings                 = each.value.cache.query_strings
    compression_enabled           = each.value.cache.compression_enabled
    content_types_to_compress     = each.value.cache.content_types_to_compress
  }
}

resource "azurerm_cdn_frontdoor_custom_domain" "this" {
  for_each                 = var.custom_domains
  name                     = substr(replace("${each.key}-${each.value.dns_zone.name}", ".", "-"), 0, 24)
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  host_name                = "${each.key}.${each.value.dns_zone.name}"
  dns_zone_id              = each.value.dns_zone.id

  tls {
    certificate_type    = each.value.tls.certificate_type
  }
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "this" {
  for_each                       = var.custom_domains
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.this[each.key].id
  cdn_frontdoor_route_ids        = [for k, v in azurerm_cdn_frontdoor_route.this : v.id]
}

module "txt_record" {
  source              = "app.terraform.io/ptonini-org/dns-record/azurerm"
  version             = "~> 1.0.0"
  for_each            = var.custom_domains
  resource_group_name = var.rg.name
  name                = "_dnsauth.${each.key}"
  type                = "txt"
  records             = [azurerm_cdn_frontdoor_custom_domain.this[each.key].validation_token]
  zone_name           = each.value.dns_zone.name
}

module "cname_record" {
  source              = "app.terraform.io/ptonini-org/dns-record/azurerm"
  version             = "~> 1.0.0"
  for_each            = var.custom_domains
  resource_group_name = var.rg.name
  name                = each.key
  type                = "cname"
  records             = [azurerm_cdn_frontdoor_endpoint.this.host_name]
  zone_name           = each.value.dns_zone.name
  depends_on = [
    azurerm_cdn_frontdoor_route.this
  ]
}