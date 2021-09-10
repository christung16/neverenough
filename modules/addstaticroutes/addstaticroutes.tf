terraform {
  required_providers {
    aci = {
        source = "CiscoDevNet/aci"
        version = "0.7.1"
    }
  }
}


variable "fabric_node_dn" {
  type = string
}

variable "static_routes" {
  type = list
}

variable "name" {
  type = string
}

variable "external_network_instance_profile_dn" {
  type = string
}


resource "aci_l3out_static_route" "staticroute" {
  for_each = {
      for route in var.static_routes: "${var.name}.${route.subnet}.${route.next_hop}" => route
  }
  fabric_node_dn = "${var.fabric_node_dn}"
  ip = each.value.subnet
}

resource "aci_l3out_static_route_next_hop" "nexthop" {
  for_each = {
      for route in var.static_routes: "${var.name}.${route.subnet}.${route.next_hop}" => route
  }
  static_route_dn = aci_l3out_static_route.staticroute[each.key].id
  nh_addr = each.value.next_hop
}

resource "aci_l3_ext_subnet" "l3extsubnet" {
  for_each = {
      for route in var.static_routes: "${var.name}.${route.subnet}.${route.next_hop}" => route
  }
  external_network_instance_profile_dn = var.external_network_instance_profile_dn
  ip = each.value.subnet
  scope = try (each.value.scope, [ "shared-rtctrl" ])
}
