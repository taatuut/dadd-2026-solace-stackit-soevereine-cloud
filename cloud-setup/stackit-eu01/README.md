# STACKIT eu01 (Duitsland) -- sovereign broker (gevoelige PII)

Rol: eindpunt voor **gevoelige persoonsgegevens** (bijv. individuele
slimme-meterstanden gekoppeld aan klant-ID, facturatiegebeurtenissen). Dit is
de klasse die conceptueel "#noexport" is in de presentatie: mag uitsluitend
naar de soevereine, Europese, niet-hyperscaler-omgeving.

## Uitgangspunt (bijgewerkt)

STACKIT wordt naar verwachting **komende week algemeen beschikbaar (GA)** in
Solace Cloud, met dezelfde self-service deployment-ervaring als AWS, Azure en
GCP (gewoon te kiezen als datacenter in de console/API, geen aparte
Controlled-Availability/BYOK-procedure meer nodig). Zodra dat zo is, maak je
de service hier exact zo aan als bij AWS/Azure (zie die READMEs als
sjabloon):

1. Solace Cloud > Cluster Manager > **+ Create Service**.
2. Cloud provider: **STACKIT**, regio: **eu01** (bevestig de exacte
   Solace-regio-code in de dropdown -- bij AWS bleek dit een
   provider-specifiek label als `eks-us-east-1a` te zijn, geen kale
   regionaam).
3. Service class: **Enterprise**, 250 connecties, HA Group -- zelfde als AWS/Azure.
4. Servicenaam: `ez-dadd-2026-stackit-eu01` (zelfde stijl als de andere services).
5. Message VPN: laat auto-genereren of zet 'm handmatig; hoeft niet
   "enewable" te zijn.
6. Publish-client-username aanmaken (gebruikt door de REST Delivery
   Point's REST-consumer), ACL-profiel dat **alleen publiceren** toestaat
   op `enewable/eu/pii/>`, SMF- en REST-host:port (verwacht 55443/TLS resp.
   9443/TLS) noteren.
7. Maak screenshots van elke stap in
   `../../screenshots/STACKIT-of-GCP-interim/`, net als bij AWS.
6. `STACKIT_*`-variabelen in `../../local-broker/.env` bijwerken en
   `../../local-broker/semp/configure-local-broker.sh` en
   `configure-rdp-export.sh` opnieuw draaien (idempotent) -- verder
   verandert er niets (topics, ACL's, RDP-naam blijven gelijk).

Alternatief via API:
`../solace-cloud-api/create-service.sh enewable-stackit-eu01
<datacenterId-voor-stackit-eu01> ENTERPRISE_250_HIGHAVAILABILITY enewable`
(zoek de exacte `datacenterId` op zodra STACKIT in
`GET .../missionControl/datacenters` verschijnt).

## Tot het zover is: interim mimic op GCP Belgium

Zolang STACKIT nog niet beschikbaar is in Solace Cloud, gebruikt de demo een
**tijdelijke stand-in**: een Solace Cloud HA-service op **GCP, regio
europe-west1 (België)**. Zie
[`../gcp-europe-west1-interim/README.md`](../gcp-europe-west1-interim/README.md)
voor de opzet -- functioneel identiek voor de demo (zelfde topics, zelfde
ACL, zelfde RDP-naam `rdp-stackit`), alleen de fysieke locatie en
provider wijken tijdelijk af van het uiteindelijke soevereine doel.

**Zodra STACKIT GA is:** maak de STACKIT eu01-service aan volgens de stappen
hierboven, werk `local-broker/.env` bij met de nieuwe host/VPN/credentials,
en trek de GCP-interim-service in Solace Cloud in. Er hoeft verder niets in
de topologie, ACL's of RDP-configuratie te veranderen.

## Waarom deze klasse sowieso op een soevereine (niet-hyperscaler) omgeving moet

Ongeacht of het tijdelijk GCP of straks STACKIT is: behandel het wachtwoord
van de publish-client-username als een geheim -- dit is de gevoeligste route
in de demo. Zodra STACKIT actief is, is de opzet ook conceptueel compleet:
geen enkele hyperscaler-eigenaar (Amerikaans of anderszins) in de keten voor
deze dataklasse.
