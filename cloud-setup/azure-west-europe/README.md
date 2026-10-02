# Azure West Europe (Nederland) -- Solace Cloud broker (niet-persoonlijke EU-data)

Rol: eindpunt voor **niet-persoonlijke, EU-gebonden** operationele data (bijv.
geaggregeerde netbelasting per postcodegebied, geanonimiseerde
verbruikstrends). Deze data mag niet buiten de EU, maar is niet
privacygevoelig genoeg om de sovereign-only (STACKIT) route te vereisen --
een bewuste middenklasse tussen "publiek" en "PII", die in de presentatie
overeenkomt met het "governed sharing / allowlist"-idee (alleen geminimaliseerde
data mag oversteken).

> Let op: Azure's regio "West Europe" staat fysiek in Nederland
> (Amsterdam-datacenters), dus dit voldoet aan "moet in Europa blijven".
> Voor een striktere sovereignty-garantie (geen Amerikaanse hyperscaler,
> ook al staat de data fysiek in de EU) zou je in een latere iteratie ook
> deze klasse naar STACKIT of een andere Europese aanbieder kunnen
> verplaatsen -- zie `../../docs/cloud-brokers.md`, sectie "Wat ontbreekt of
> kan beter".

## Service

Datacenter `aks-westeurope`, "Developer 100"-tier, Message VPN `enewable`.
SMF-poort 55443/TLS, REST-poort 9443/TLS (zelfde hostname als SMF) --
exacte hostnames staan in `../../local-broker/.env` en in de
Terraform-output (`terraform output -json azure_service`). Screenshots van
de aanmaak staan in [`../../screenshots/Azure/`](../../screenshots/Azure/).

## Publish-toegang

`enewable-local-bridge` + ACL-profiel `acl-enewable-local-bridge`
(publish-only op `enewable/eu/ops/>`) worden aangemaakt via
`../solace-cloud-api/configure-remote-bridge-users.sh` (SEMP-admin-username
`mission-control-manager`). Credentials staan in `../../local-broker/.env`
en worden gebruikt door de REST Delivery Point's REST-consumer
(`../../local-broker/semp/configure-rdp-export.sh`).

## Aanmaken

De aanbevolen route is **Terraform**
([`../terraform/README.md`](../terraform/README.md)).

Alternatief, handmatig via de console:

1. Solace Cloud > Cluster Manager > **+ Create Service**.
2. Cloud provider + regio kiezen (regio-codes zijn provider-specifiek,
   bijv. `aks-westeurope` voor deze Azure-service).
3. Service class: **Developer 100**.
4. Servicenaam: volg dezelfde stijl, `ez-dadd-2026-<provider>-<regio>`.
5. Message VPN: `enewable`.
6. Wacht tot de service status "Running" is (doorgaans enkele minuten) en
   maak screenshots van elke stap.

Alternatief via API: `../solace-cloud-api/create-service.sh
ez-dadd-2026-<naam> <datacenterId> DEVELOPER enewable`
(zoek de exacte `datacenterId` op via `GET .../missionControl/datacenters`).

Zie ook `../../docs/cloud-brokers.md` voor de bredere toelichting en
`../../docs/topologie.md` voor het plaatje.
