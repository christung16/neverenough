# AUTHOR(s): Chris Tung <yitung@cisco.com>

terraform {
  required_providers {
    fmc = {
      source = "CiscoDevNet/fmc"
      version = ">=0.1.1"
    }
  }
}

variable "name" {
  type = string
}

variable "sync_fmc_object" {
  type = bool
}

variable "subnet" {
  type = string
}

variable "vrf_name" {
  type = string
}

resource "fmc_network_objects" "objects" {
  count = var.sync_fmc_object ? 1 : 0
  name = format("%s__%s__%s", var.vrf_name,var.name,replace(cidrsubnet(var.subnet,0,0),"/","_"))
  value = cidrsubnet(var.subnet,0,0)
}

