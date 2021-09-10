# AUTHOR(s): Chris Tung <yitung@cisco.com>

terraform {
  required_providers {
    vsphere = {
      source = "hashicorp/vsphere"
      version = "2.0.2"
    }
  }
}

variable "name" {
  type = string
}

variable "vcenter_datacenter_name" {
  type = string
}

variable "esxi_hosts" {
  type = list
}

variable "uplinks" {
  type = list
}

data "vsphere_datacenter" "dc" {
  name = var.vcenter_datacenter_name
}

resource "vsphere_folder" "folder" {
  path = var.name
  type = "network"
  datacenter_id = data.vsphere_datacenter.dc.id
#  lifecycle {
#    prevent_destroy = true
#  }
}

data "vsphere_host" "hosts" {
  for_each = {
    for host in var.esxi_hosts: host => host
  }
  name = each.value
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "vsphere_distributed_virtual_switch" "dvs" {
  datacenter_id = data.vsphere_datacenter.dc.id
  name = var.name
  folder = vsphere_folder.folder.path
  max_mtu = 9000
  link_discovery_protocol = "lldp"
  link_discovery_operation = "both"
  dynamic "host" {
    for_each = {
      for host in var.esxi_hosts: host => host
    }
    content {
      host_system_id = data.vsphere_host.hosts[host.value].id
      devices = var.uplinks
    }
  }
  lifecycle {
    ignore_changes = [pvlan_mapping, host, link_discovery_protocol]
  }
}
