# AWS US East -- Solace Cloud HA broker (PUBLIC data)

Rol: eindpunt voor **publieke** Enewable-data (bijv. day-ahead energieprijzen,
publieke weerdata voor opwekvoorspelling). Geen persoonsgegevens, geen
concurrentiegevoelige data -- dit is bewust de minst gevoelige klasse en
daarom de klasse die naar een Amerikaanse hyperscaler-regio mag.

## Status: aangemaakt

Service **`ez-dadd-2026-eks-us-east-1a`** is aangemaakt (28/09/2026).
Screenshots van elke stap staan in
[`../../screenshots/AWS/`](../../screenshots/AWS/).

| Veld | Waarde |
|---|---|
| Cloud / regio | AWS, `eks-us-east-1a` |
| Service class | Enterprise, 250 connecties, 50 GB message spool |
| High Availability | HA Group (active/standby/monitoring, 3 brokers) |
| Broker release | 10.26 |
| Cluster | **Public** (zie `../../docs/cloud-brokers.md`, "Netwerktoegang") |
| Message VPN | `ez-dadd-2026-eks-us-east-1` (auto-gegenereerd uit de servicenaam) |
| SMF-hostname | `mr-connection-07w9t1ah76x.messaging.solace.cloud` (poort nog te bevestigen op de Connect-tab, standaard 55443/TLS) |

## Status: bridge-toegang ingericht

✅ `enewable-local-bridge` + ACL-profiel `acl-enewable-local-bridge`
(publish-only op `enewable/public/>`) zijn aangemaakt via
`../solace-cloud-api/configure-remote-bridge-users.sh` (SEMP-admin-username
`mission-control-manager`). Credentials staan in `../../local-broker/.env`.

## Nog te doen voor deze service

1. **Connect-tab**: exacte SMF-poort (verwacht 55443, TLS) bevestigen.
2. ~~Client-username + ACL-profiel aanmaken~~ ✅ gedaan, zie "Status:
   bridge-toegang ingericht" hierboven.
3. ~~Host, VPN-naam en credentials in `../../local-broker/.env` invullen~~ ✅
   gedaan (VPN-naam `ez-dadd-2026-eks-us-east-1` en bridge-credentials
   staan er al in onder de `AWS_*`-variabelen).

## Aanmaken (voor de volgende services, Azure/STACKIT/GCP-interim, ter referentie)

1. Solace Cloud > Cluster Manager > **+ Create Service**.
2. Cloud provider + regio kiezen (regio-codes zijn provider-specifiek, bijv.
   `eks-us-east-1a` voor deze AWS-service -- zoek de exacte waarde op in de
   Region-dropdown, neem 'm niet zomaar over uit dit document).
3. Service class: **Enterprise**, 250 connecties, HA Group -- zelfde als
   hierboven, voor consistentie.
4. Servicenaam: volg dezelfde stijl, `ez-dadd-2026-<provider>-<regio>`.
5. Message VPN: laat auto-genereren (hoeft niet overeen te komen tussen
   services) of zet 'm handmatig onder "Advanced Connection Options".
6. Wacht tot de service status "Running" is (doorgaans enkele minuten) en
   maak screenshots van elke stap, net als bij AWS.

Alternatief via API: `../solace-cloud-api/create-service.sh
ez-dadd-2026-<naam> <datacenterId> ENTERPRISE_250_HIGHAVAILABILITY`
(zoek de exacte `datacenterId` op via `GET .../missionControl/datacenters`).

Zie ook `../../docs/cloud-brokers.md` voor de bredere toelichting en
`../../docs/topologie.md` voor het plaatje.
