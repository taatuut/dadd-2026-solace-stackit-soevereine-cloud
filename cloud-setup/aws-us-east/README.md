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

## Nog te doen voor deze service

1. **Connect-tab**: exacte SMF-poort (verwacht 55443, TLS) bevestigen.
2. **Manage > Client Usernames**: een client-username aanmaken die de
   lokale bridge mag gebruiken, bijv. `enewable-local-bridge`, met een
   ACL-profiel dat **alleen publiceren** toestaat op `enewable/public/>`
   (de bridge levert de doorgestuurde berichten hier af als publisher --
   niet als subscriber; vergelijk met hoe de lokale ACL-profielen in
   `../../local-broker/semp/configure-local-broker.sh` zijn opgezet).
   **Gebruik niet de standaard `solace-cloud-client`-username hiervoor** -- die wordt door de "Try Me!"-tab van deze service gebruikt om tijdens de live demo de binnenkomende berichten te laten zien, en heeft standaard een ruim ACL-profiel. Een nieuwe, dedicated username met een eigen, beperkt ACL-profiel houdt de "Try Me!"-subscriptie werkend en laat bovendien precies zien waar de demo over gaat: gegarandeerde, ACL-afgedwongen scheiding per dataklasse, niet toevallige scheiding via topic-naamgeving.
   Handmatig via de UI, of automatisch met `../solace-cloud-api/configure-remote-bridge-users.sh` (SEMP v2 Config API van deze broker zelf -- vul eerst `*_SEMP_HOST`/`*_SEMP_ADMIN_USER`/`*_SEMP_ADMIN_PASSWORD` in `../../local-broker/.env` in, te vinden op de Connect-tab; het wachtwoord voor `enewable-local-bridge` staat er al in).
3. Host, VPN-naam en credentials in `../../local-broker/.env` invullen
   onder de `AWS_*`-variabelen (VPN-naam mag je nu al invullen, is geen
   geheim: `ez-dadd-2026-eks-us-east-1`).

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
