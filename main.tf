# AUTHOR(s): Chris Tung <yitung@cisco.com>

terraform {
  required_providers {
    aci = {
      source = "CiscoDevNet/aci"
      version = "0.7.1"
    }
    fmc = {
      source = "CiscoDevNet/fmc"
      version = ">=0.1.1"
    }
    vsphere = {
      source = "hashicorp/vsphere"
      version = "2.0.2"
    }
  }
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "MyOfficeLab"

    workspaces {
      name = "neverenough"
    }
  }
}

provider "aci" {
  username = var.aci_user.username
  password = var.aci_user.password
  url = var.aci_user.url
  insecure = true
}

provider "fmc" {
  fmc_username = var.fmc_user.username
  fmc_password = var.fmc_user.password
  fmc_host = var.fmc_user.url
  fmc_insecure_skip_verify = true
}

provider "vsphere" {
  user = var.vcenter_user.username
  password = var.vcenter_user.password
  vsphere_server = var.vcenter_user.url
  allow_unverified_ssl = true
}

resource "aci_tenant" "this" {
  description = var.tenant.description
  name = var.tenant.name
}

resource "aci_application_profile" "anps" {
  for_each = var.anps
  tenant_dn = aci_tenant.this.id
  name = each.value.name
}

resource "aci_vrf" "vrfs" {
  for_each = var.vrfs
  tenant_dn = aci_tenant.this.id
  name = each.value.name
}

resource "aci_bridge_domain" "bds" {
  for_each = var.bds
  tenant_dn = aci_tenant.this.id
  name = each.value.name
  description = each.value.display_name
  relation_fv_rs_ctx = aci_vrf.vrfs[each.value.vrf_name].id
}

resource "aci_application_epg" "epgs" {
  for_each = var.epgs
  application_profile_dn = aci_application_profile.anps[each.value.anp_name].id
  name = each.value.name
  description = each.value.display_name
  relation_fv_rs_bd = aci_bridge_domain.bds[each.value.bd_name].id
}

locals {
  bd_subnets = flatten ([
    for bd_key, bd in var.bds : [
      for subnet in bd.subnets : {
        bd_name = bd_key
        bd_subnet = subnet
        
      }
    ]
  ])
}

resource "aci_subnet" "subnets" {
  for_each = {
    for subnet in local.bd_subnets: "${subnet.bd_name}.${subnet.bd_subnet}" => subnet
  }
  parent_dn = aci_bridge_domain.bds[each.value.bd_name].id
  ip = each.value.bd_subnet
  scope = ["public", "shared"]
}

resource "aci_filter" "filters" {
  for_each = var.filters
    tenant_dn = aci_tenant.this.id
    description = try (each.value.display_name, each.value.name)
    name = each.value.name
}

resource "aci_filter_entry" "filterentry" {
  for_each = var.filters
  filter_dn = aci_filter.filters[each.key].id
  description = try (each.value.entry_display_name, each.value.name)
  name = try (each.value.entry_name, each.value.name)
  ether_t = try (each.value.ether_type, "unspecified")
  d_from_port = try (each.value.destination_from, "unspecified")
  d_to_port = try (each.value.destination_to, "unspecified")
  prot = try (each.value.ip_protocol, "unspecified")
  stateful = each.value.stateful
}

resource "aci_contract_subject" "subjects" {
  for_each = var.contracts
  contract_dn = aci_contract.contracts[each.key].id
  description = format ("%s%s",each.value.contract_name, "_subj")
  name = format ("%s%s", each.value.contract_name, "_subj")
  relation_vz_rs_subj_filt_att = formatlist ("%s/%s%s", aci_tenant.this.id,"flt-",each.value.filter_list)
  rev_flt_ports = "yes"
}

resource "aci_contract" "contracts" {
  for_each = var.contracts
  tenant_dn = aci_tenant.this.id
  description = each.value.display_name
  name = each.value.contract_name
  scope = each.value.scope
}

resource "aci_epg_to_contract" "consumer" {
  for_each = var.contracts
  application_epg_dn = aci_application_epg.epgs[each.value.anp_epg_consumer.epg_name].id
  contract_dn = aci_contract.contracts[each.key].id
  contract_type = "consumer"
}

resource "aci_epg_to_contract" "provider" {
  for_each = var.contracts
  application_epg_dn = aci_application_epg.epgs[each.value.anp_epg_provider.epg_name].id
  contract_dn = aci_contract.contracts[each.key].id
  contract_type = "provider"
}

resource "aci_contract_subject" "esg_subjects" {
  for_each = var.esg_contracts
  contract_dn = aci_contract.esg_con[each.key].id
  description = format ("%s%s",each.value.contract_name, "_subj")
  name = format ("%s%s", each.value.contract_name, "_subj")
  relation_vz_rs_subj_filt_att = formatlist ("%s/%s%s", aci_tenant.this.id,"flt-",each.value.filter_list)
  rev_flt_ports = "yes"
}

resource "aci_contract" "esg_con" {
  for_each = var.esg_contracts
  tenant_dn = aci_tenant.this.id
  description = each.value.display_name
  name = each.value.contract_name
  scope = each.value.scope
}

resource "aci_vlan_pool" "vlan_pool" {
  for_each = var.vlan_pool
  name = each.value.name
  alloc_mode = each.value.alloc_mode
}

resource "aci_ranges" "vlan_range" {
  for_each = var.vlan_pool
  vlan_pool_dn = aci_vlan_pool.vlan_pool[each.key].id
  from = each.value.from
  to = each.value.to
}

resource "aci_attachable_access_entity_profile" "vmm_vmware_aaep" {
  for_each = var.vmm_vmware
  name = each.value.aaep_name
  relation_infra_rs_dom_p = [ aci_vmm_domain.vmm_domain[each.key].id ]
}

resource "aci_vmm_domain" "vmm_domain" {
  for_each = var.vmm_vmware
  provider_profile_dn = each.value.provider_profile_dn
  name = each.value.name
  relation_infra_rs_vlan_ns = aci_vlan_pool.vlan_pool[each.value.vlan_pool].id
//  depends_on = [
//    module.dvs
//  ]
}

resource "aci_vmm_credential" "vmm_cred" {
  for_each = var.vmm_vmware
  vmm_domain_dn = aci_vmm_domain.vmm_domain[each.key].id
  name = format( "%s%s", each.value.name,"-credential")
  annotation = "orchestrator:terraform"
  pwd = var.vcenter_user.password
  usr = var.vcenter_user.username
  lifecycle {
    ignore_changes = [
      pwd,
    ]
  }
}

resource "aci_vmm_controller" "gen_com_ctrl" {
  for_each = var.vmm_vmware
  vmm_domain_dn = aci_vmm_domain.vmm_domain[each.key].id
  name = format( "%s%s", each.value.name,"-controller")
  host_or_ip = each.value.vcenter_host_or_ip
  root_cont_name = each.value.vcenter_datacenter_name
  dvs_version = each.value.dvs_version
  relation_vmm_rs_acc = aci_vmm_credential.vmm_cred[each.key].id
}

resource "aci_vswitch_policy" "dvs" {
  for_each = var.vmm_vmware
  vmm_domain_dn = aci_vmm_domain.vmm_domain[each.key].id
  annotation = "orchestrator:terraform"

}

resource "aci_attachable_access_entity_profile" "phydomain_aaep" {
  for_each = var.phydomain
  name = each.value.aaep_name
  relation_infra_rs_dom_p = [ aci_physical_domain.phydom[each.key].id ]
}

resource "aci_physical_domain" "phydom" {
  for_each = var.phydomain
  name = each.value.name
  relation_infra_rs_vlan_ns = aci_vlan_pool.vlan_pool[each.value.vlan_pool].id
}

resource "aci_attachable_access_entity_profile" "l3domain_aaep" {
  for_each = var.l3domain
  name = each.value.aaep_name
  relation_infra_rs_dom_p = [ aci_l3_domain_profile.l3domain[each.key].id ]
}

resource "aci_l3_domain_profile" "l3domain" {
  for_each = var.l3domain
  name = each.value.name
  relation_infra_rs_vlan_ns = aci_vlan_pool.vlan_pool[each.value.vlan_pool].id
}

resource "aci_l3_outside" "l3out" {
  for_each = var.l3outs
  tenant_dn =  aci_tenant.this.id
  name = each.value.name
  description = each.value.description
  enforce_rtctrl = try (each.value.enforce_rtctrl, [ "export" ])
  relation_l3ext_rs_ectx = aci_vrf.vrfs[each.value.vrf_name].id
  relation_l3ext_rs_l3_dom_att = aci_l3_domain_profile.l3domain[each.value.l3domain_name].id

}

resource "aci_logical_node_profile" "lnode" {
  for_each = var.l3outs
  l3_outside_dn = aci_l3_outside.l3out[each.key].id
  name = format ("%s%s", each.value.name, "_nodeProfile")
}

resource "aci_logical_node_to_fabric_node" "rtrid" {
  for_each = var.l3outs
  logical_node_profile_dn = aci_logical_node_profile.lnode[each.key].id
  tdn = "topology/${each.value.lnodes.pod_name}/node-${each.value.lnodes.leaf_block}"
  rtr_id = each.value.lnodes.rtr_id
  rtr_id_loop_back = "yes"
}

resource "aci_logical_interface_profile" "l_intf_prof" {
  for_each = var.l3outs
  logical_node_profile_dn = aci_logical_node_profile.lnode[each.key].id
  name = replace("${each.value.lnodes.pod_name}-node-${each.value.lnodes.leaf_block}-${each.value.lnodes.interface}", "/", "-")
}

resource "aci_l3out_path_attachment" "l_intf_prof_port" {
  for_each = var.l3outs
  logical_interface_profile_dn = "${aci_logical_interface_profile.l_intf_prof[each.key].id}"
  target_dn = "topology/${each.value.lnodes.pod_name}/paths-${each.value.lnodes.leaf_block}/pathep-[${each.value.lnodes.interface}]"
  if_inst_t = each.value.lnodes.ifInstT
  addr = each.value.lnodes.addr
  encap = try (each.value.lnodes.encap, "unknown")
  mac = try (each.value.lnodes.mac, "00:22:BD:F8:19:FF")
}

resource "aci_external_network_instance_profile" "extprofile" {
  for_each = var.l3outs
  l3_outside_dn = aci_l3_outside.l3out[each.key].id
  name = each.value.lnodes.ext_epg_name
}

module "addstaticroutes" {
  source = "./modules/addstaticroutes"
  for_each = var.l3outs
  static_routes = each.value.lnodes.static_routes
  fabric_node_dn = aci_logical_node_to_fabric_node.rtrid[each.key].id
  external_network_instance_profile_dn = aci_external_network_instance_profile.extprofile[each.key].id
  name = each.value.name
}

resource "aci_cdp_interface_policy" "cdp" {
  for_each = var.cdp
  name = each.value.name
  admin_st = each.value.admin_st
}

resource "aci_lldp_interface_policy" "lldp" {
  for_each = var.lldp
  name = each.value.name
  description = each.value.description
  admin_tx_st = each.value.admin_tx_st
  admin_rx_st = each.value.admin_rx_st
}

resource "aci_lacp_policy" "lacp" {
  for_each = var.lacp
  name = each.value.name
  ctrl = tolist(each.value.ctrl)
  mode = each.value.mode
}

module "accessportgroup" {
  source = "./modules/accessportgroup"
  for_each = var.access_port_group_policy
  name = each.value.name
  lldp_status = each.value.lldp_status
  cdp_status  = each.value.cdp_status
  aaep_name = each.value.aaep_name
  leaf_profile = each.value.leaf_profile
  leaf_block = each.value.leaf_block
  ports = each.value.ports
  depends_on = [
    aci_cdp_interface_policy.cdp,
    aci_lldp_interface_policy.lldp,
    aci_attachable_access_entity_profile.vmm_vmware_aaep,
    aci_attachable_access_entity_profile.phydomain_aaep,
    aci_attachable_access_entity_profile.l3domain_aaep,
  ]
}

module "vpc" {
  source = "./modules/vpc"
  for_each = var.vpc
  name = each.value.name
  lldp_status = each.value.lldp_status
  cdp_status  = each.value.cdp_status
  port_channel_status = each.value.port_channel_status
  aaep_name = each.value.aaep_name
  leaf_profile = each.value.leaf_profile
  leaf_block = each.value.leaf_block
  lag_t = each.value.lag_t
  ports = each.value.ports
  depends_on = [
    aci_cdp_interface_policy.cdp,
    aci_lldp_interface_policy.lldp,
    aci_lacp_policy.lacp,
    aci_attachable_access_entity_profile.vmm_vmware_aaep,
    aci_attachable_access_entity_profile.phydomain_aaep,
    aci_attachable_access_entity_profile.l3domain_aaep,
  ]
}

module "epg_to_domains" {
  source = "./modules/epg_to_domains"
  for_each = {
    for k, v in var.epgs : k => v if length(var.epgs) > 0
  }
  application_epg_dn = aci_application_epg.epgs[each.key].id
#  name = each.value.name
#  display_name = each.value.display_name
#  anp_name = each.value.anp_name
#  bd_name = each.value.bd_name
  domains = each.value.domains
  depends_on = [
    aci_physical_domain.phydom,
    aci_vmm_domain.vmm_domain
  ]
}


data "aci_fabric_path_ep" "path_ep" {
  for_each = var.static_vlan_epgs
  pod_id = each.value.pod_id
  node_id = each.value.node_id
  name = each.value.eth_name
}

resource "aci_epg_to_static_path" "static_path" {
  for_each = var.static_vlan_epgs
  application_epg_dn = aci_application_epg.epgs[each.key].id
  tdn = data.aci_fabric_path_ep.path_ep[each.key].id
#  tdn = format ("%s%s%s","topology/pod-1/protpaths-105-106/pathep-[",each.value.vpc_name,"]")
  encap = each.value.encap
  mode = each.value.mode
  instr_imedcy = "immediate"
}

resource "aci_endpoint_security_group" "esg" {
  for_each = var.esgs
  application_profile_dn = aci_application_profile.anps[each.value.anp_name].id
  name = each.value.name
  relation_fv_rs_scope = aci_vrf.vrfs[each.value.vrf_name].id
  dynamic relation_fv_rs_cons {
    for_each = {
      for consumer in each.value.contract_consumer: consumer => consumer
    }
    content {
      target_dn = aci_contract.esg_con[relation_fv_rs_cons.value].id
    }
  }
  dynamic relation_fv_rs_prov {
    for_each = {
      for provider in each.value.contract_provider: provider => provider
    }
    content {
      target_dn = aci_contract.esg_con[relation_fv_rs_prov.value].id
    }
  }
}

# Create L4-L7 Device.
resource "aci_rest" "device" {
    for_each = var.sg
    path    = "api/node/mo/${aci_tenant.this.id}/lDevVip-${each.value.name}.json"
    payload = <<EOF
{
		"vnsLDevVip": {
			"attributes": {
				"activeActive": "no",
				"annotation": "",
				"contextAware": "single-Context",
				"devtype": "${each.value.devtype}",
				"dn": "${aci_tenant.this.id}/lDevVip-${each.value.name}",
				"funcType": "GoTo",
				"isCopy": "no",
				"managed": "no",
				"mode": "legacy-Mode",
				"name": "${each.value.name}",
				"nameAlias": "",
				"packageModel": "",
				"promMode": "no",
				"svcType": "FW",
				"trunking": "no",
				"userdom": ":all:"
			},
			"children": [{
				"vnsRsALDevToPhysDomP": {
					"attributes": {
						"annotation": "",
						"tDn": "uni/phys-${each.value.phydomain_name}",
						"userdom": ":all:"
					}
				}
			}, {
				"vnsLIf": {
					"attributes": {
						"annotation": "",
						"encap": "${each.value.inside_vlan}",
						"lagPolicyName": "",
						"name": "cl-i-${each.value.name}",
						"nameAlias": "",
						"userdom": ":all:"
					},
					"children": [{
						"vnsRsCIfAttN": {
							"attributes": {
								"annotation": "",
								"tDn": "${aci_tenant.this.id}/lDevVip-${each.value.name}/cDev-${each.value.name}/cIf-in-${each.value.inside_leaf_block}-${each.value.inside_card}-${each.value.inside_port}",
								"userdom": ":all:"
							}
						}
					}]
				}
			}, {
				"vnsLIf": {
					"attributes": {
						"annotation": "",
						"encap": "${each.value.outside_vlan}",
						"lagPolicyName": "",
						"name": "cl-o-${each.value.name}",
						"nameAlias": "",
						"userdom": ":all:"
					},
					"children": [{
						"vnsRsCIfAttN": {
							"attributes": {
								"annotation": "",
								"tDn": "${aci_tenant.this.id}/lDevVip-${each.value.name}/cDev-${each.value.name}/cIf-out-${each.value.outside_leaf_block}-${each.value.outside_card}-${each.value.outside_port}",
								"userdom": ":all:"
							}
						}
					}]
				}
			}, {
				"vnsCDev": {
					"attributes": {
						"annotation": "",
						"cloneCount": "0",
						"devCtxLbl": "",
						"host": "",
						"isCloneOperation": "no",
						"isTemplate": "no",
						"name": "${each.value.name}",
						"nameAlias": "",
						"userdom": ":all:",
						"vcenterName": "",
						"vmName": ""
					},
					"children": [{
						"vnsCIf": {
							"attributes": {
								"annotation": "",
								"encap": "unknown",
								"name": "in-${each.value.inside_leaf_block}-${each.value.inside_card}-${each.value.inside_port}",
								"nameAlias": "",
								"userdom": ":all:",
								"vnicName": ""
							},
							"children": [{
								"vnsRsCIfPathAtt": {
									"attributes": {
										"annotation": "",
										"tDn": "topology/pod-1/paths-${each.value.inside_leaf_block}/pathep-[eth${each.value.inside_card}/${each.value.inside_port}]",
										"userdom": ":all:"
									}
								}
							}]
						}
					}, {
						"vnsCIf": {
							"attributes": {
								"annotation": "",
								"encap": "unknown",
								"name": "out-${each.value.outside_leaf_block}-${each.value.outside_card}-${each.value.outside_port}",
								"nameAlias": "",
								"userdom": ":all:",
								"vnicName": ""
							},
							"children": [{
								"vnsRsCIfPathAtt": {
									"attributes": {
										"annotation": "",
										"tDn": "topology/pod-1/paths-${each.value.outside_leaf_block}/pathep-[eth${each.value.outside_card}/${each.value.outside_port}]",
										"userdom": ":all:"
									}
								}
							}]
						}
					}]
				}
			}]
		}
	}
EOF
}


# Create L4-L7 Service Graph template.
resource "aci_l4_l7_service_graph_template" "this" {
    for_each = var.sg
    tenant_dn                         = aci_tenant.this.id
    name                              = format ("%s%s", "sg-",each.value.name)
    description                       = each.value.description
    l4_l7_service_graph_template_type = "legacy"
    ui_template_type                  = "UNSPECIFIED"
}

# Create L4-L7 Service Graph template node.
resource "aci_function_node" "this" {
    for_each = var.sg
    l4_l7_service_graph_template_dn = aci_l4_l7_service_graph_template.this[each.key].id
    name                            = each.value.site_nodes[0].node_name
    func_template_type              = "FW_ROUTED"
    func_type                       = "GoTo"
    is_copy                         = "no"
    managed                         = "no"
    routing_mode                    = "Redirect"
    sequence_number                 = "0"
    share_encap                     = "no"
    relation_vns_rs_node_to_l_dev   = "${aci_tenant.this.id}/lDevVip-${each.value.name}"
}

# Create L4-L7 Service Graph template T1 connection.
resource "aci_connection" "t1-n1" {
    for_each = var.sg
    l4_l7_service_graph_template_dn = aci_l4_l7_service_graph_template.this[each.key].id
    name           = "C2"
    adj_type       = "L3"
    conn_dir       = "provider"
    conn_type      = "external"
    direct_connect = "no"
    unicast_route  = "yes"
    relation_vns_rs_abs_connection_conns = [
        aci_l4_l7_service_graph_template.this[each.key].term_prov_dn,
        aci_function_node.this[each.key].conn_provider_dn
    ]
}

# Create L4-L7 Service Graph template T2 connection.
resource "aci_connection" "n1-t2" {
    for_each = var.sg
    l4_l7_service_graph_template_dn = aci_l4_l7_service_graph_template.this[each.key].id
    name                            = "C1"
    adj_type                        = "L3"
    conn_dir                        = "provider"
    conn_type                       = "external"
    direct_connect                  = "no"
    unicast_route                   = "yes"
    relation_vns_rs_abs_connection_conns = [
        aci_l4_l7_service_graph_template.this[each.key].term_cons_dn,
        aci_function_node.this[each.key].conn_consumer_dn
    ]
}

# Create L4-L7 Logical Device Context / Devices Selection Policies.
resource "aci_logical_device_context" "this" {
    for_each = var.sg
    tenant_dn                          = aci_tenant.this.id
    ctrct_name_or_lbl                  = each.value.contract_name
    graph_name_or_lbl                  = format ("%s%s", "sg-",each.value.name)
    node_name_or_lbl                   = aci_function_node.this[each.key].name
    relation_vns_rs_l_dev_ctx_to_l_dev = "${aci_tenant.this.id}/lDevVip-${each.value.name}"
#    relation_vns_rs_l_dev_ctx_to_l_dev = aci_rest.device[each.value.name].id
    depends_on = [
      aci_rest.device,
    ]

}

# Create L4-L7 Logical Device Interface Contexts.
resource "aci_logical_interface_context" "consumer" {
  for_each = var.sg
	logical_device_context_dn        = aci_logical_device_context.this[each.key].id
	conn_name_or_lbl                 = "consumer"
	l3_dest                          = "yes"
	permit_log                       = "no"
  relation_vns_rs_l_if_ctx_to_l_if = "${aci_tenant.this.id}/lDevVip-${each.value.name}/lIf-cl-o-${each.value.name}"
  relation_vns_rs_l_if_ctx_to_bd   = aci_bridge_domain.bds[each.value.outside_bd_name].id
  relation_vns_rs_l_if_ctx_to_svc_redirect_pol = aci_service_redirect_policy.pbr[each.value.outside_pbr_name].id
  depends_on = [
    aci_rest.device,
  ]
}

resource "aci_logical_interface_context" "provider" {
  for_each = var.sg
	logical_device_context_dn        = aci_logical_device_context.this[each.key].id
	conn_name_or_lbl                 = "provider"
	l3_dest                          = "yes"
	permit_log                       = "no"
  relation_vns_rs_l_if_ctx_to_l_if = "${aci_tenant.this.id}/lDevVip-${each.value.name}/lIf-cl-i-${each.value.name}"
  relation_vns_rs_l_if_ctx_to_bd   = aci_bridge_domain.bds[each.value.inside_bd_name].id
  relation_vns_rs_l_if_ctx_to_svc_redirect_pol = aci_service_redirect_policy.pbr[each.value.inside_pbr_name].id
  depends_on = [
    aci_rest.device,
  ]
}

resource "aci_l4_l7_service_graph_template" "sg_template" {
  for_each = var.sg
  tenant_dn = aci_tenant.this.id
  name = format ("%s%s", "sg-", each.value.name)
  description = each.value.description
}

resource "aci_contract_subject" "subj" {
  for_each = var.sg
  contract_dn = "${aci_tenant.this.id}/brc-${each.value.contract_name}"
  name = format ("%s%s", each.value.contract_name, "_subj")
  relation_vz_rs_subj_graph_att = aci_l4_l7_service_graph_template.sg_template[each.key].id
}

# Create IP SLA Monitoring Policy
resource "aci_rest" "ipsla" {
    for_each = var.pbr
    path    = "api/node/mo/${aci_tenant.this.id}/ipslaMonitoringPol-${each.value.ipsla_name}.json"
    payload = <<EOF
{
	"fvIPSLAMonitoringPol": {
			"attributes": {
				"dn": "${aci_tenant.this.id}/ipslaMonitoringPol-${each.value.ipsla_name}",
				"name": "${each.value.ipsla_name}",
				"rn": "ipslaMonitoringPol-${each.value.ipsla_name}",
				"status": "created"
			},
			"children": []
	}
}
EOF  
}

# Create Redirect Health Group
resource "aci_rest" "rh" {
    for_each = var.pbr
    path    = "api/node/mo/${aci_tenant.this.id}/svcCont/redirectHealthGroup-${each.value.rh_grp_name}.json"
    payload = <<EOF
{
	"vnsRedirectHealthGroup": {
		"attributes": {
			"dn": "${aci_tenant.this.id}/svcCont/redirectHealthGroup-${each.value.rh_grp_name}",
			"name": "${each.value.rh_grp_name}",
			"rn": "redirectHealthGroup-${each.value.rh_grp_name}",
			"status": "created"
		},
		"children": []
	}
}
EOF
}

resource "aci_service_redirect_policy" "pbr" {
  for_each = var.pbr
  tenant_dn = aci_tenant.this.id
  name = each.value.name
  dest_type = "L3"
  relation_vns_rs_ipsla_monitoring_pol = "${aci_tenant.this.id}/ipslaMonitoringPol-${each.value.ipsla_name}"
#  relation_vns_rs_ipsla_monitoring_pol = aci_rest.ipsla[each.value.name].id
  depends_on = [
    aci_rest.ipsla,
  ]
}

resource "aci_destination_of_redirected_traffic" "pbr" {
  for_each = var.pbr
  service_redirect_policy_dn = aci_service_redirect_policy.pbr[each.value.name].id
  ip = each.value.ip
  mac = upper(each.value.mac)
  relation_vns_rs_redirect_health_group = "${aci_tenant.this.id}/svcCont/redirectHealthGroup-${each.value.rh_grp_name}"
#  relation_vns_rs_redirect_health_group = aci_rest.rh[each.value.name].id
  depends_on = [
    aci_rest.rh,
  ]
}


#####################################
# vcenter                           #
#####################################

module "dvs" {
  source = "./modules/dvs"
  for_each = var.vmm_vmware
  name = each.value.name
  vcenter_datacenter_name = each.value.vcenter_datacenter_name
  esxi_hosts = each.value.esxi_hosts
  uplinks = each.value.uplinks
}

module "fmc" {
  source = "./modules/fmc"
  for_each = var.bds
  sync_fmc_object = try(each.value.sync_fmc_object, false)
  name = each.value.name
  subnets = each.value.subnets
  vrf_name = each.value.vrf_name
}


#####################################
# create vm                           #
#####################################


resource "time_sleep" "wait_15_seconds" {
  create_duration = "15s"
/*
  triggers = {
    num_cpus = "2"
  }
*/
  depends_on = [
    aci_application_epg.epgs,
    aci_vmm_domain.vmm_domain,
    aci_vmm_controller.gen_com_ctrl,
    module.epg_to_domains,
    module.accessportgroup,
    module.vpc
  ]

}

module "vm" {
  source = "./modules/vm"
  for_each = var.vm
  name = each.value.name
  vm_template = each.value.vm_template
  datacenter = each.value.datacenter
  cluster = each.value.cluster
  datastore = each.value.datastore
  guest_id = each.value.guest_id
  num_cpus = each.value.num_cpus
  memory = each.value.memory
  disk_size = each.value.disk_size
  network = each.value.network
  host_name = each.value.host_name
  domain = each.value.domain
  ipv4_address = each.value.ipv4_address
  ipv4_netmask = each.value.ipv4_netmask
  ipv4_gateway = each.value.ipv4_gateway
  use_static_mac = each.value.use_static_mac
  mac_address = each.value.mac_address
  depends_on = [
    time_sleep.wait_15_seconds
  ]
}


