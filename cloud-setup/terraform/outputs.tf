# The exact attribute structure of a solacecloud_service resource (SMF
# host, REST host/port, generated SEMP admin/editor/viewer credentials)
# could not be independently verified against a live service for this
# repo (network access to api.solace.cloud is blocked from this
# assistant session, see ../../docs/cloud-brokers.md, "Netwerktoegang").
# So: output the whole resource object per service, marked sensitive
# (the message_vpn block is expected to carry generated credentials), and
# inspect the REAL structure yourself after apply with e.g.:
#   terraform output -json aws_service | jq .
# See this folder's README.md, "Na terraform apply", for how to map
# whatever comes out of that onto local-broker/.env.

output "aws_service" {
  value     = solacecloud_service.aws_us_east
  sensitive = true
}

output "azure_service" {
  value     = solacecloud_service.azure_west_europe
  sensitive = true
}

output "stackit_service" {
  value     = solacecloud_service.stackit_eu01
  sensitive = true
}
