variable "aws_azure_org_api_token" {
  description = "Mission Control API token for the Solace Cloud organization that hosts the AWS and Azure services (Mission Control > API Tokens, scope: Create Services + My/Organization Services). NEVER commit the real value -- set it in terraform.tfvars (gitignored) or the TF_VAR_aws_azure_org_api_token env var."
  type        = string
  sensitive   = true
}

variable "aws_azure_org_base_url" {
  description = "Mission Control REST API base URL for the AWS/Azure org's Home Cloud. Confirm in the console (My Account/Org settings) -- do not assume it is always https://api.solace.cloud/."
  type        = string
  default     = "https://api.solace.cloud/"
}

variable "stackit_org_api_token" {
  description = "Mission Control API token for the Solace Cloud organization that hosts the STACKIT service. This is a DIFFERENT org from aws_azure_org_api_token, so a different token -- do not reuse the same one."
  type        = string
  sensitive   = true
}

variable "stackit_org_base_url" {
  description = "Mission Control REST API base URL for the STACKIT org's Home Cloud. May differ from aws_azure_org_base_url since it is a separate org -- check its own console."
  type        = string
  default     = "https://api.solace.cloud/"
}

variable "datacenter_id_aws" {
  description = "Solace Cloud datacenterId for the AWS service. Look up the exact, CURRENT value via GET {aws_azure_org_base_url}api/v2/missionControl/datacenters using the aws_azure_org token -- these are account/contract-specific and change over time (see ../solace-cloud-api/create-service.sh's own long-standing warning not to hardcode this blindly). The old value (something like eks-us-east-1a) may or may not still be valid in the new org."
  type        = string
}

variable "datacenter_id_azure" {
  description = "Solace Cloud datacenterId for the Azure West Europe service. Same lookup caveat as datacenter_id_aws."
  type        = string
}

variable "datacenter_id_stackit" {
  description = "Solace Cloud datacenterId for the STACKIT service. If STACKIT is now confirmed GA as its own selectable datacenter (see TODO.md, 'STACKIT GA-check'), use the real STACKIT eu01 id. If it is NOT yet selectable, point this at a GCP europe-west1 interim datacenter id instead, exactly like the previous manually-created stand-in, and revisit once STACKIT really is available."
  type        = string
}

variable "service_class_id" {
  description = "Solace Cloud serviceClassId for all 3 services. Emil asked for the 'Developer 100' tier for all three. Sources disagree on the exact string: the REST API docs list serviceClassId \"developer\" (lowercase) for the non-HA, ~100-connection free/dev tier, while the Terraform provider's own schema shows a default of \"DEVELOPER\" (uppercase). CONFIRM THE EXACT STRING before relying on the default -- run `terraform plan` and read any validation error, or check GET {base_url}api/v2/missionControl/serviceClasses with either token."
  type        = string
  default     = "DEVELOPER"
}

variable "message_vpn_name" {
  description = "Message VPN name to set EXPLICITLY on all 3 services, instead of letting Solace Cloud auto-generate/truncate one from the service name -- that auto-naming is what caused the 26-character-truncation + lowercasing surprises documented in ../../docs/cloud-brokers.md last time."
  type        = string
  default     = "enewable"
}

variable "name_prefix" {
  description = "Prefix for all 3 service names, matching the existing naming convention documented in ../../docs/cloud-brokers.md ('ez-dadd-2026-<provider>-<regio>')."
  type        = string
  default     = "ez-dadd-2026"
}
