variable "name" {
  type = string
}

variable "rg" {
  type = object({
    name     = string
    location = string
    id       = string
  })
}

variable "profile_sku_name" {
  default  = "Standard_AzureFrontDoor"
  nullable = false
}

variable "origin_group" {
  type = object({
    session_affinity_enabled = optional(bool, true)
    load_balancing = optional(object({
      sample_size                 = optional(number, 4)
      successful_samples_required = optional(number, 3)
    }), {})
    health_probe = optional(object({
      path                = optional(string, "/")
      request_type        = optional(string, "HEAD")
      protocol            = optional(string, "Https")
      interval_in_seconds = optional(number, 100)
    }), {})
  })
  default  = {}
  nullable = false
}

variable "origins" {
  type = map(object({
    enabled                        = optional(bool, true)
    host_name                      = string
    http_port                      = optional(number, 80)
    https_port                     = optional(number, 443)
    original_host_header           = optional(string)
    priority                       = optional(number, 1)
    weight                         = optional(number, 1000)
    certificate_name_check_enabled = optional(bool, true)
  }))
}

variable "routes" {
  type = map(object({
    supported_protocols    = optional(set(string), ["Http", "Https"])
    patterns_to_match      = optional(set(string), ["/*"])
    forwarding_protocol    = optional(string, "HttpsOnly")
    link_to_default_domain = optional(bool, true)
    https_redirect_enabled = optional(bool, true)
    cache = optional(object({
      query_string_caching_behavior = optional(string, "IgnoreSpecifiedQueryStrings")
      query_strings                 = optional(set(string), ["account", "settings"])
      compression_enabled           = optional(bool, true)
      content_types_to_compress     = optional(set(string), ["text/html", "text/javascript", "text/xml"])
    }), {})
  }))
  default = {
    default = {}
  }
  nullable = false
}

variable "custom_domains" {
  type = map(object({
    host_name = optional(string)
    dns_zone = object({
      id   = string
      name = string
    })
    tls = optional(object({
      certificate_type = optional(string, "ManagedCertificate")
    }), {})
  }))
  default = {}
}

