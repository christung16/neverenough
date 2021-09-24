# FY22 Hackathon: Single and Simple interface to accelerate multi-domain adoption with DevOps Automation"
# by Team “Never Enough”

DevOps Automation can streamline daily operations and eliminate the need to navigate through multiple GUI interfaces to accomplish such routine tasks as house-keeping static routes, VLANs or EPGs. 

This Hackathon example is to showcase how we leverage Terraform Cloud, Webex Chatbot and Webhook programming to integrate Cisco Application Centric Infrastructure (ACI), Cisco Firepower Management Center (FMC) and Virtualized Compute infrastructure (VMware in this example) to automate end-to-end Data Center infrastructural provisoning.
![image](https://user-images.githubusercontent.com/8743281/134628271-3bb3a46a-14cb-44d8-99e3-905cf8563da2.png)

## Pre-requisites

The repository is originally developed to be triggered by a [Terraform Cloud](https://www.terraform.io/cloud) account to execute planning, cost estimation and then deployment. Therefore, the login credentials to APIC controller as well as such parameters as the target ACI tenant name are defined in "Variables" section of the Terraform Cloud environment. If the code is to be tested in a private Terraform environment, one may have to manually include these parameters in the variable file.

## Requirements
Name | Version
---- | -------
[terraform](https://www.terraform.io/downloads.html)| >= 1.0.4

## Providers
Name | Version
---- | -------
aci | >= 0.7.1
fmc | >= 0.1.1
vsphere | >= 2.0.2

## Compatibility
This sample is developed and tested with Cisco ACI 5.2(1g) and [Terraform Cloud](https://www.terraform.io/cloud) 1.0.4. However, it is expected to work with Cisco ACI >=4.2 and terraform >=0.13.

## Use Case Description

A 3-Tier application composing of Web, App and Database Tiers with 2-armed mode Service Graph between App-Tier and Database-Tier is a very typical application profile. This sample serves as a quick reference to create all the necessary components on APIC with Terraform HCL. More complicated applicatioon profiles can be derived from this sample.

![image](https://user-images.githubusercontent.com/8743281/132814548-073215a4-253e-45a2-bea8-0064635266fa.png)

# End-to-end provisioning automation comprises of 3 main steps:

## Step 1: Solicit end-user input via a Service Portal
End users input parameters such as EPGs, BDs, Contracts, VM names and what-nots will be gathered by a service portal.
![image](https://user-images.githubusercontent.com/8743281/132814864-a001be68-cbc7-4b9c-9b34-993cce5628c7.png)

![image](https://user-images.githubusercontent.com/8743281/132815154-eb478eb0-44be-4b4c-914a-3e2e4a317b68.png)

The input will be converted into **tfvars** files to be consumed by Terraform Cloud. The update of these files to GitHub repository will trigger Terraform Cloud to kick-start its processing.
![image](https://user-images.githubusercontent.com/8743281/132815293-17f206b6-40c5-491e-b0f7-b61169ff5905.png)

## Step 2: Terraform Cloud and Cisco Multi-Cloud Infrastructure Integration

Terraform files (**main.tf**, **variables.tf.json**) will be modified and pushed to github repository which is linked to Terraform Cloud. A Terraform Cloud agent on-premise will push the changes to the APIC controller, the Firepower Management Center and the hypervisor controller.

![image](https://user-images.githubusercontent.com/8743281/132816143-1ba133b0-5736-442e-81bc-6270d2807adc.png)

## Step 3: Approver will be notified by Webex Chabot for review and approval

A Webhook application will be notified by Terraform Cloud on the change request. This webhook will call Webex Chatbot to formulate an actionable message and post it on the webex team room for attention and follow-up. Once the approver has approved or denied the change request, the webhook will trigger Terraform to continue run or discard the change request. It will also delete the webex actionable message and post another confirmation message as record. 
![image](https://user-images.githubusercontent.com/8743281/134628207-0451a6cb-f68f-42ae-acf3-c7802dbf83c2.png)

## Installation

1. Install and setup your Terraform environment
2. Copy files (**main.tf** and **variable.tf**) onto your Terraform runtime environment
3. Deploy the webhook program (**app/main.py**) in your environment which can be accessed by Terraform Cloud and Webex Teams API.
4. Service Portal can be deployed in your web serving environment which can access your github repository.

## Configuration

All terraform variables in this use case are around the 3-tier application sample. It can be modified to cater for any application profile or scenario.

## Usage

*To provision:*
 * Execute with usual *terraform init*, *terraform plan* and *terraform apply*

*To destroy:*
 * Destroy the deployment with *terraform destroy* command.

## Credits and references

1. [Cisco Infrastructure As Code](https://developer.cisco.com/iac/)
2. [ACI provider Terraform](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs)
3. [FMC provider Terraform](https://registry.terraform.io/providers/CiscoDevNet/fmc/latest/docs)
