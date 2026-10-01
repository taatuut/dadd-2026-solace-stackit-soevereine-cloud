# Recreates the 3 Solace Cloud event broker services that were deleted
# (see ../../PLAN.md section 13, point 40, and ../../TODO.md). Mirrors the
# manual setup already documented in ../aws-us-east/README.md,
# ../azure-west-europe/README.md and ../stackit-eu01/README.md -- read
# those first if anything here is unclear; they are the ground truth for
# what "the same as before" means (naming convention, roles per class).
#
# Scope: this only provisions the SERVICES themselves (Mission Control
# level, via the solacecloud provider). It does NOT create the
# publish-only client-username/ACL-profile on each new broker -- that is
# SEMP-level config, still handled afterward by the existing
# ../solace-cloud-api/configure-remote-bridge-users.sh (see this folder's
# README.md, "Na terraform apply", for the full sequence).

resource "solacecloud_service" "aws_us_east" {
  provider         = solacecloud.aws_azure_org
  name             = "${var.name_prefix}-aws-us-east"
  datacenter_id    = var.datacenter_id_aws
  service_class_id = var.service_class_id
  message_vpn_name = var.message_vpn_name
}

resource "solacecloud_service" "azure_west_europe" {
  provider         = solacecloud.aws_azure_org
  name             = "${var.name_prefix}-azure-westeurope"
  datacenter_id    = var.datacenter_id_azure
  service_class_id = var.service_class_id
  message_vpn_name = var.message_vpn_name
}

resource "solacecloud_service" "stackit_eu01" {
  provider         = solacecloud.stackit_org
  name             = "${var.name_prefix}-stackit-eu01"
  datacenter_id    = var.datacenter_id_stackit
  service_class_id = var.service_class_id
  message_vpn_name = var.message_vpn_name
}
