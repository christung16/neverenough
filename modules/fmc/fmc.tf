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

variable "subnets" {
  type = list
}

variable "vrf_name" {
  type = string
}

module "fmc_network_object" {
  source = "./modules/fmc_network_object"
  for_each = {
    for subnet in var.subnets: subnet => subnet
  }
  name = var.name
  vrf_name = var.vrf_name
  sync_fmc_object = var.sync_fmc_object
  subnet = each.value
}

