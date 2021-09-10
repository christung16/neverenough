#!/usr/bin/env python

import json
import os
import github3
import datetime
import credential


def hcl_underlay(
    name, lldp_status, cdp_status, aaep_name, leaf_profile, leaf_block, port
):
    with open("terraform.auto.tfvars.json", "r") as tfvars_file:
        tfvars = json.load(tfvars_file)
        tfvars_file.close()

    access_port_group_policy = {
        "leaf_access_port_101_1_19_phydomain": {
            "aaep_name": "aaep_first_app_fpr_phydomain",
            "cdp_status": cdp_status,
            "leaf_block": [leaf_block],
            "leaf_profile": leaf_profile,
            "lldp_status": lldp_status,
            "name": name,
            "ports": [
                {"from_card": "1", "from_port": port, "to_card": "1", "to_port": port}
            ],
        }
    }
    tfvars["access_port_group_policy"] = access_port_group_policy

    with open("terraform.auto.tfvars.json", "w") as tfvars_file, open(
        "archive/terraform.auto.tfvars.json." + str(datetime.datetime.utcnow()), "w"
    ) as tfvars_archive:
        json.dump(tfvars, tfvars_file, indent=4, sort_keys=True)
        json.dump(tfvars, tfvars_archive, indent=4, sort_keys=True)
        tfvars_file.close()
        tfvars_archive.close()
    # upload ti github
    github_update()


def hcl_overlay(epg1, bd1, epg2, bd2, epg3, bd3):
    with open("terraform.auto.tfvars.json", "r") as tfvars_file:
        tfvars = json.load(tfvars_file)
        tfvars_file.close()

    epgs = {
        epg1: {
            "anp_name": "first_app_ap",
            "bd_name": bd1,
            "display_name": epg1,
            "domains": [
                {"name": "first_app_vswitch", "type": "vmm_vmware"},
                {"name": "first_app_bare_metal_phydomain", "type": "phydomain"},
            ],
            "name": epg1,
        },
        epg2: {
            "anp_name": "first_app_ap",
            "bd_name": bd2,
            "display_name": epg2,
            "domains": [{"name": "first_app_vswitch", "type": "vmm_vmware"}],
            "name": epg2,
        },
        epg3: {
            "anp_name": "first_app_ap",
            "bd_name": bd3,
            "display_name": epg3,
            "domains": [{"name": "first_app_vswitch", "type": "vmm_vmware"}],
            "name": epg3,
        },
    }

    tfvars["epgs"] = epgs

    with open("terraform.auto.tfvars.json", "w") as tfvars_file, open(
        "archive/terraform.auto.tfvars.json." + str(datetime.datetime.utcnow()), "w"
    ) as tfvars_archive:
        json.dump(tfvars, tfvars_file, indent=4, sort_keys=True)
        json.dump(tfvars, tfvars_archive, indent=4, sort_keys=True)
        tfvars_file.close()
        tfvars_archive.close()
    # upload ti github
    github_update()


def hcl_policy(consumer_epg1, provider_epg1, consumer_epg2, provider_epg2):
    with open("terraform.auto.tfvars.json", "r") as tfvars_file:
        tfvars = json.load(tfvars_file)
        tfvars_file.close()

    contracts = {
        "Con_app_epg_to_database_epg": {
            "anp_epg_consumer": {"anp_name": "first_app_ap", "epg_name": consumer_epg2},
            "anp_epg_provider": {"anp_name": "first_app_ap", "epg_name": provider_epg2},
            "contract_name": "Con_app_epg_to_database_epg",
            "directives": ["none"],
            "display_name": "Con_app_epg_to_database_epg",
            "filter_list": ["tcp_3306", "icmp"],
            "filter_type": "bothWay",
            "scope": "tenant",
        },
        "Con_web_epg_to_app_epg": {
            "anp_epg_consumer": {"anp_name": "first_app_ap", "epg_name": consumer_epg1},
            "anp_epg_provider": {"anp_name": "first_app_ap", "epg_name": provider_epg1},
            "contract_name": "Con_web_epg_to_app_epg",
            "directives": ["none"],
            "display_name": "Con_web_epg_to_app_epg",
            "filter_list": ["tcp_22", "icmp"],
            "filter_type": "bothWay",
            "scope": "tenant",
        },
    }

    tfvars["contracts"] = contracts

    with open("terraform.auto.tfvars.json", "w") as tfvars_file, open(
        "archive/terraform.auto.tfvars.json." + str(datetime.datetime.utcnow()), "w"
    ) as tfvars_archive:
        json.dump(tfvars, tfvars_file, indent=4, sort_keys=True)
        json.dump(tfvars, tfvars_archive, indent=4, sort_keys=True)
        tfvars_file.close()
        tfvars_archive.close()
    # upload ti github
    github_update()


def hcl_vm(web_vm, app_vm, db_vm, web_epg, app_epg, db_epg):
    with open("terraform.auto.tfvars.json", "r") as tfvars_file:
        tfvars = json.load(tfvars_file)
        tfvars_file.close()

    vm = {
        app_vm: {
            "cluster": "HX-CLUSTER",
            "datacenter": "HX-DC",
            "datastore": "HX-DATASTORE",
            "disk_size": "16",
            "domain": "hklab.local",
            "guest_id": "ubuntu64Guest",
            "host_name": app_vm,
            "ipv4_address": "192.168.20.1",
            "ipv4_gateway": "192.168.20.254",
            "ipv4_netmask": "24",
            "mac_address": "00:50:56:9a:14:01",
            "memory": "3072",
            "name": "app01_first_app",
            "network": "first_app_tn|first_app_ap|" + app_epg,
            "num_cpus": "2",
            "use_static_mac": True,
            "vm_template": "Ubuntu-20.04.2(Template)",
        },
        db_vm: {
            "cluster": "HX-CLUSTER",
            "datacenter": "HX-DC",
            "datastore": "HX-DATASTORE",
            "disk_size": "16",
            "domain": "hklab.local",
            "guest_id": "ubuntu64Guest",
            "host_name": db_vm,
            "ipv4_address": "192.168.21.1",
            "ipv4_gateway": "192.168.21.254",
            "ipv4_netmask": "24",
            "mac_address": "00:50:56:9a:15:01",
            "memory": "3072",
            "name": "database01_first_app",
            "network": "first_app_tn|first_app_ap|" + db_epg,
            "num_cpus": "2",
            "use_static_mac": True,
            "vm_template": "Ubuntu-20.04.2(Template)",
        },
        web_vm: {
            "cluster": "HX-CLUSTER",
            "datacenter": "HX-DC",
            "datastore": "HX-DATASTORE",
            "disk_size": "16",
            "domain": "hklab.local",
            "guest_id": "ubuntu64Guest",
            "host_name": web_vm,
            "ipv4_address": "192.168.10.1",
            "ipv4_gateway": "192.168.10.254",
            "ipv4_netmask": "24",
            "mac_address": "00:50:56:9a:0a:01",
            "memory": "3072",
            "name": "web01_first_app",
            "network": "first_app_tn|first_app_ap|" + web_epg,
            "num_cpus": "1",
            "use_static_mac": True,
            "vm_template": "Ubuntu-20.04.2(Template)",
        },
    }

    tfvars["vm"] = vm

    with open("terraform.auto.tfvars.json", "w") as tfvars_file, open(
        "archive/terraform.auto.tfvars.json." + str(datetime.datetime.utcnow()), "w"
    ) as tfvars_archive:
        json.dump(tfvars, tfvars_file, indent=4, sort_keys=True)
        json.dump(tfvars, tfvars_archive, indent=4, sort_keys=True)
        tfvars_file.close()
        tfvars_archive.close()
    # upload ti github
    github_update()


def hcl_get_epgs():
    with open("terraform.auto.tfvars.json", "r") as tfvars_file:
        tfvars = json.load(tfvars_file)
        tfvars_file.close()
    epg_list = tfvars["epgs"].keys()
    return epg_list


def github_update():
    token = credential.github_token
    github = github3.login(token=token)
    repo = github.repository(credential.github_user, credential.github_repo)
    file = "terraform.auto.tfvars.json"
    file_list = [e[0] for e in repo.directory_contents("/")]
    with open(file, "rb") as fd:
        content = fd.read()
    if file in file_list:
        upload = repo.file_contents(file)
        upload.update(
            "Terraform HCL file update, commit at " + str(datetime.datetime.utcnow()),
            content,
        )
    else:
        repo.create_file(
            path=file, message="Terraform HCL file".format(file), content=content
        )
