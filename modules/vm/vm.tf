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

variable "vm_template" {
  type = string
}

variable "datacenter" {
  type = string
}

variable "cluster" {
  type = string
}

variable "datastore" {
  type = string
}

variable "guest_id" {
  type = string
}

variable "num_cpus" {
  type = string
}

variable "memory" {
  type = string
}

variable "disk_size" {
  type = string
}

variable "network" {
  type = string
}

variable "host_name" {
  type = string
}

variable "domain" {
  type = string
}

variable "ipv4_address" {
  type = string
}

variable "ipv4_netmask" {
  type = string
}

variable "ipv4_gateway" {
  type = string
}

variable "use_static_mac" {
  type = bool
}

variable "mac_address" {
  type = string
}

data "vsphere_datacenter" "dc" {
    name = var.datacenter
}

data "vsphere_compute_cluster" "cluster" {
    name          = var.cluster
    datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "datastore" {
    name = var.datastore
    datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "vm_network" {
    name = var.network
    datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
    name = var.vm_template
    datacenter_id = data.vsphere_datacenter.dc.id
}

resource "vsphere_virtual_machine" "vm" {
    name = var.name
    resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
    datastore_id = data.vsphere_datastore.datastore.id
    guest_id = var.guest_id
    num_cpus = var.num_cpus
    memory = var.memory
    wait_for_guest_net_timeout = 0
    network_interface {
        network_id = data.vsphere_network.vm_network.id
        adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
        use_static_mac = try (var.use_static_mac, "false")
        mac_address = try (var.mac_address, "")
        
    }
    disk {
        label = "disk0"
        size = var.disk_size
        eagerly_scrub = "true"
        thin_provisioned = "false"
    }
    clone {
        template_uuid = data.vsphere_virtual_machine.template.id
        customize {
            linux_options {
                host_name = var.host_name
                domain = var.domain
            }
            network_interface {
                ipv4_address = var.ipv4_address
                ipv4_netmask = var.ipv4_netmask
            }
            ipv4_gateway = var.ipv4_gateway
        }
    }
}
