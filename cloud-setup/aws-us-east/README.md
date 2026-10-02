# AWS US East - Solace Cloud broker (PUBLIC data)

Rol: eindpunt voor **publieke** Enewable-data (bijv. day-ahead energieprijzen,
publieke weerdata voor opwekvoorspelling). Geen persoonsgegevens, geen
concurrentiegevoelige data - dit is bewust de minst gevoelige klasse en
daarom de klasse die naar een Amerikaanse hyperscaler-regio mag.

## Service

Datacenter `eks-us-east-1a`, "Developer 100"-tier, Message VPN `enewable`.
SMF-poort 55443/TLS, REST-poort 9443/TLS (zelfde hostname als SMF) -
exacte hostnames staan in `../../local-broker/.env` en in de
Terraform-output (`terraform output -json aws_service`). Screenshots van
de aanmaak staan in [`../../screenshots/AWS/`](../../screenshots/AWS/).

## Publish-toegang

`enewable-local-bridge` + ACL-profiel `acl-enewable-local-bridge`
(publish-only op `enewable/public/>`) worden aangemaakt via
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
   bijv. `eks-us-east-1a` voor deze AWS-service - zoek de exacte waarde
   op in de Region-dropdown, neem 'm niet zomaar over uit dit document).
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
