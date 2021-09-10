# AUTHOR(s): Chris Tung <yitung@cisco.com>

terraform {
  required_providers {
    aci = {
        source = "CiscoDevNet/aci"
        version = "0.7.1"
    }
  }
}

variable "application_epg_dn" {
    type = string
}

variable "domains" {
    type = list
}

data "aci_physical_domain" "phydom" {
    for_each = { 
        for domain in var.domains : "${domain.name}" => domain if domain.type == "phydomain"
    }
    name = each.value.name
}

data "aci_vmm_domain" "vmm_domain" {
    for_each = {
        for domain in var.domains : "${domain.name}" => domain if domain.type == "vmm_vmware"
    }
    provider_profile_dn = "uni/vmmp-VMware"
    name = each.value.name
}

resource "aci_epg_to_domain" "this" {
    for_each = {
        for domain in var.domains:  "${domain.name}" => domain
    }
    application_epg_dn = var.application_epg_dn
    tdn = "${each.value.type == "vmm_vmware" ? data.aci_vmm_domain.vmm_domain[each.value.name].id : data.aci_physical_domain.phydom[each.value.name].id}"
    vmm_allow_promiscuous = "${each.value.type == "vmm_vmware" ? "accept" : "reject"}"
    vmm_forged_transmits = "${each.value.type == "vmm_vmware" ? "accept" : "reject"}"
    allow_micro_seg = "${each.value.type == "vmm_vmware" ? true : false}"
    instr_imedcy = "${each.value.type == "vmm_vmware" ? "immediate" : "lazy"}"
    res_imedcy = "${each.value.type == "vmm_vmware" ? "immediate" : "lazy"}"
}
