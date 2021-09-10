# AUTHOR(s): Chris Tung <yitung@cisco.com>

terraform {
  required_providers {
    aci = {
        source = "CiscoDevNet/aci"
        version = "0.7.1"
    }
  }
}

variable "name" {
  type = string
}

variable "lldp_status" {
  type = string
}

variable "cdp_status" {
  type = string
}

variable "aaep_name" {
  type = string
}

variable "leaf_profile" {
  type = string
}

variable "leaf_block" {
  type = list
}

variable "ports" {
  type = list
}

/*
variable "from_card" {
  type = string
}

variable "from_port" {
  type = string
}

variable "to_card" {
  type = string
}

variable "to_port" {
  type = string
}
*/


/*
data "aci_vmm_domain" "vds" {
  provider_profile_dn = "uni/vmmp-VMware"
  name = var.vmm_vcenter.vds_name
}

resource "aci_attachable_access_entity_profile" "vmm_vcenter" {
  name = var.vmm_vcenter.aaep_name
  relation_infra_rs_dom_p = [data.aci_vmm_domain.vds.id]
}
*/

data "aci_lldp_interface_policy" "lldp_status" {
  name = var.lldp_status
}

data "aci_cdp_interface_policy" "cdp_status" {
  name = var.cdp_status
}

data "aci_attachable_access_entity_profile" "aaep" {
  name = var.aaep_name
}

resource "aci_leaf_access_port_policy_group" "leaf_access_port_pg" {
  name = var.name
  relation_infra_rs_lldp_if_pol = data.aci_lldp_interface_policy.lldp_status.id
  relation_infra_rs_cdp_if_pol = data.aci_cdp_interface_policy.cdp_status.id
  relation_infra_rs_att_ent_p = data.aci_attachable_access_entity_profile.aaep.id
}

resource "aci_leaf_interface_profile" "leaf_interface_profile" {
  name = format("%s%s",var.name,"_intf_p")
}

resource "aci_access_port_selector" "access_port_selector" {
  for_each = {
    for port in var.ports: "${var.name}.${port.from_card}-${port.from_port}.${port.to_card}-${port.to_port}" => port
  }
  leaf_interface_profile_dn = aci_leaf_interface_profile.leaf_interface_profile.id
  name = format("%s%s",each.key,"_selector")
  access_port_selector_type = "range"
  relation_infra_rs_acc_base_grp = aci_leaf_access_port_policy_group.leaf_access_port_pg.id
}

resource "aci_access_port_block" "access_port_block" {
  for_each = { 
    for port in var.ports: "${var.name}.${port.from_card}-${port.from_port}.${port.to_card}-${port.to_port}" => port 
  }
  access_port_selector_dn = aci_access_port_selector.access_port_selector[each.key].id
  name = format("%s%s",var.name,"_port_block")
  from_card = each.value.from_card
  from_port = each.value.from_port
  to_card = each.value.to_card
  to_port = each.value.to_port
/*
  from_card = var.from_card
  from_port = var.from_port
  to_card = var.to_card
  to_port = var.to_port
*/
}

resource "aci_leaf_profile" "leaf_profile" {        
  name = var.leaf_profile
  relation_infra_rs_acc_port_p = [ aci_leaf_interface_profile.leaf_interface_profile.id ]
  leaf_selector {
    name = format("%s%s",var.leaf_profile,"_leaf_selector")
    switch_association_type = "range"
    dynamic "node_block" {
      for_each = { for leaf_block in var.leaf_block : leaf_block => leaf_block }
      content {
        name = format("%s%s","node_",node_block.value)
        from_ = node_block.value
        to_ = node_block.value
      }
    }
  }
}

