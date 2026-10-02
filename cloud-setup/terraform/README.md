# Terraform: de 3 cloud-broker services aanmaken

Terraform-opzet om de 3 Solace Cloud event broker services (AWS, Azure,
STACKIT) aan te maken - een alternatief voor de console-wizard en
`../solace-cloud-api/create-service.sh` (die blijven staan als
handmatige/REST-referentie, zie `../README.md`).

## Wat dit wel en niet doet

- **Wel**: de 3 services zelf aanmaken (Mission Control-niveau) -
  `name`, `datacenter_id`, `service_class_id` ("Developer 100"-tier, zie
  `variables.tf`), en een EXPLICIETE `message_vpn_name` (`enewable`, om een
  auto-gegenereerde/afgekapte naam te voorkomen - zie
  `../../docs/cloud-brokers.md`).
- **Niet**: de publish-only `enewable-local-bridge`-client-username + ACL
  -profiel op elke nieuwe broker. Dat is SEMP-niveau-configuratie op de
  broker zelf, geen Mission-Control-resource, en blijft voor nu de taak
  van `../solace-cloud-api/configure-remote-bridge-users.sh` (zie "Na
  terraform apply" hieronder). Dat zou met een losse `solacebroker`-
  Terraform-provider (zie Solace's GitHub) ook geautomatiseerd kunnen
  worden - bewust buiten scope voor nu, zie `../../TODO.md`.

## Twee Solace Cloud-organisaties, dus twee providers

AWS + Azure staan in één org, STACKIT in een andere. Daarom twee
`provider "solacecloud"`-blokken met een eigen `alias` in `provider.tf`
(`aws_azure_org` resp. `stackit_org`), elk met zijn EIGEN API-token èn
zijn eigen Home-Cloud `base_url` (niet per se dezelfde - check dit per
org in de console, "My Account"/org-instellingen).

## Vóór je begint: dingen die JIJ moet checken/invullen (dit kan de assistent niet)

Netwerktoegang naar `api.solace.cloud` en de broker-hostnames is vanuit de
Cowork-sessie (zowel de cloud-container als de sandbox op je Mac) geblokkeerd
- zie `../../docs/cloud-brokers.md`, "Netwerktoegang vanuit deze sessie".
`terraform init`/`plan`/`apply` moet dus, net als `create-service.sh`,
door jezelf in je eigen, gewone terminal gedraaid worden.

1. **Terraform CLI installeren** (`brew install terraform` of `tfenv`),
   versie >= 1.5.
2. **Twee API-tokens aanmaken**, één per org (Mission Control > API
   Tokens, scope "Create Services" + Organization Services).
3. **Home-Cloud base_url per org bevestigen** in de console - neem niet
   zomaar `https://api.solace.cloud/` aan voor beide.
4. **De 3 `datacenterId`-waarden opzoeken**, per org met het bijbehorende
   token:
   `curl -H "Authorization: Bearer <token>" "<base_url>api/v2/missionControl/datacenters"`
   - dit zijn account-/contractspecifieke waarden die veranderen, dus
   NIET blindelings hergebruiken uit een oude screenshot (zelfde
   waarschuwing als altijd al in `../solace-cloud-api/create-service.sh`
   stond).
5. **STACKIT-datacenter-id.** STACKIT heeft een eigen, echte
   `SolaceDedicated`-datacenter (`stackitdemo-stackit-eu01-production`,
   "StackIT Production Region") - gebruik die id voor
   `datacenter_id_stackit`.
6. **`service_class_id` bevestigen.** Bronnen spreken elkaar tegen over de
   exacte schrijfwijze van de "Developer 100"-klasse: de REST-API-docs
   noemen `"developer"` (kleine letters), het Terraform-provider-schema
   zelf gebruikt als default `"DEVELOPER"` (hoofdletters). `variables.tf`
   gebruikt voorlopig `"DEVELOPER"` - `terraform plan` zal een
   validatiefout geven als dit niet klopt; corrigeer dan in
   `terraform.tfvars`.
7. `cp terraform.tfvars.example terraform.tfvars` en alles hierboven
   invullen. `terraform.tfvars` staat in `.gitignore` - commit 'm nooit.

## Draaien

```bash
cd cloud-setup/terraform
terraform init      # downloadt de (beta) solacecloud-provider
terraform plan       # controleer dit AANDACHTIG voor je apply't
terraform apply
```

De provider is **beta** (zie
[Solace Community](https://community.solace.com/t/new-beta-solace-cloud-terraform-provider-for-managing-event-broker-services/4502)) -
als `apply` op een verwarrende manier faalt, is de bewezen fallback de
handmatige console-wizard of `../solace-cloud-api/create-service.sh` (zie
`../README.md`).

`terraform apply` is asynchroon-wachtend net als de REST-API (de provider
poll't zelf tot de service "Running" is, zie `api_polling_interval` als je
dit wilt afstellen) - dit kan enkele minuten per service duren.

## Na `terraform apply`

1. Inspecteer de echte outputstructuur (deze kon niet vooraf tegen een
   live service geverifieerd worden, zie `outputs.tf`):
   ```bash
   terraform output -json aws_service | jq .
   terraform output -json azure_service | jq .
   terraform output -json stackit_service | jq .
   ```
2. Vul `../../local-broker/.env` in (`AWS_*`/`AZURE_*`/
   `STACKIT_*`-secties) met wat daar uitkomt: SMF-hostname:poort,
   REST-hostname:poort, VPN-naam (moet overal `enewable` zijn), en de
   gegenereerde SEMP-admin-credentials (de `message_vpn`-credential met de
   "manager"-rol, zichtbaar als `mission-control-manager`-user op de
   Connect-tab - bevestig dit zelf tegen de echte output).
3. Draai `../solace-cloud-api/configure-remote-bridge-users.sh` om op elke
   nieuwe broker opnieuw de publish-only `enewable-local-bridge` +
   ACL-profiel aan te maken (gebruikt de SEMP-admin-credentials uit stap 2,
   niet het Mission Control-token).
4. Draai `../../local-broker/semp/configure-local-broker.sh` en
   `configure-rdp-export.sh` opnieuw (idempotent) zodat de lokale broker
   en de 3 RDP's naar de nieuwe hosts/VPN's wijzen.
5. Loop het testplan uit `PLAN.md` sectie 12 opnieuw door om te bevestigen
   dat elke dataklasse weer op precies de juiste broker landt.

## Beperkingen / wat nog kan verbeteren

- `terraform.tfstate` bevat de gegenereerde credentials in platte tekst -
  blijft lokaal en gitignored; voor iets langduriger dan deze demo zou je
  remote state + encryptie willen (zie `../../TODO.md`, "Geheimenbeheer").
- SEMP-niveau-configuratie (ACL's, client-usernames, queues, RDP's) is nog
  niet in Terraform meegenomen - zou met Solace's `solacebroker`-provider
  kunnen, maar dat vervangt dan ook de bestaande, al-bewezen
  `local-broker/semp/*.sh`-scripts; bewust niet in deze eerste stap
  gedaan.
