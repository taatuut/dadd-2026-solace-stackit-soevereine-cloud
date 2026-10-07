# STACKIT eu01 (Duitsland) - sovereign broker (gevoelige PII)

Rol: eindpunt voor **gevoelige persoonsgegevens** (bijv. individuele
slimme-meterstanden gekoppeld aan klant-ID, facturatiegebeurtenissen). Dit is
de klasse die conceptueel "#noexport" is in de presentatie: mag uitsluitend
naar de soevereine, Europese, niet-hyperscaler-omgeving.

## Datacenter

STACKIT heeft een eigen, echte publieke regio in Solace Cloud:
datacenter-id `ske-eu01` (`datacenterType SolacePublic`, provider
`ske`, regio "Germany"), met dezelfde self-service
deployment-ervaring als AWS en Azure - gewoon te kiezen als datacenter
bij het aanmaken van de service, geen aparte
Controlled-Availability/BYOK-procedure. **Gebruik uitsluitend
`ske-eu01`.** Dezelfde Solace Cloud-organisatie bevat ook een
`stackitdemo-stackit-eu01-production`-datacenter (`datacenterType
SolaceDedicated`, provider `k8s`) - een *dedicated*, aan één
organisatie gebonden cluster dat in de Solace Cloud console onder het
generieke "Private Cloud"-icoon staat in plaats van het
STACKIT-icoon. Dit per ongeluk gekozen leverde eerder een verkeerd
geregionaliseerde service op (zie `../../PLAN.md`, sectie 13, punt 58)
- controleer `datacenterType` altijd via `GET
{stackit_org_base_url}api/v2/missionControl/datacenters` voor je een
datacenter-id overneemt.

## Aanmaken

De aanbevolen route is **Terraform**
([`../terraform/README.md`](../terraform/README.md)), dat de service
aanmaakt als "Developer 100"-tier met een EXPLICIETE Message VPN-naam
`enewable`.

Alternatief, handmatig via de console:

1. Solace Cloud > Cluster Manager > **+ Create Service**.
2. Cloud provider: **STACKIT**, regio: **eu01**, datacenter-id
   **`ske-eu01`** (`datacenterType SolacePublic`) - niet de
   `stackitdemo-stackit-eu01-production`-optie, die staat onder het
   "Private Cloud"-icoon in plaats van het STACKIT-icoon.
3. Service class: **Developer 100**.
4. Servicenaam: `ez-dadd-2026-ske-eu01` (zelfde stijl als de andere
   services).
5. Message VPN: `enewable`.
6. Publish-client-username aanmaken (gebruikt door de REST Delivery
   Point's REST-consumer), ACL-profiel dat **alleen publiceren** toestaat
   op `enewable/eu/pii/>`, SMF- en REST-host:port noteren.
7. Maak screenshots van elke stap in
   `../../screenshots/STACKIT/`.
8. `STACKIT_*`-variabelen in `../../local-broker/.env` bijwerken en
   `../../local-broker/semp/configure-local-broker.sh` en
   `configure-rdp-export.sh` opnieuw draaien (idempotent).

Alternatief via API:
`../solace-cloud-api/create-service.sh enewable-stackit-eu01
<datacenterId-voor-stackit-eu01> DEVELOPER enewable`.

## Publish-toegang

`enewable-local-bridge` + ACL-profiel `acl-enewable-local-bridge`
(publish-only op `enewable/eu/pii/>`) worden aangemaakt via
`../solace-cloud-api/configure-remote-bridge-users.sh` (SEMP-admin-username
`mission-control-manager`). Credentials staan in `../../local-broker/.env`
en worden gebruikt door de REST Delivery Point's REST-consumer
(`../../local-broker/semp/configure-rdp-export.sh`).

## Waarom deze klasse sowieso op een soevereine (niet-hyperscaler) omgeving moet

Behandel het wachtwoord van de publish-client-username als een geheim -
dit is de gevoeligste route in de demo. Voor deze dataklasse zit geen
enkele hyperscaler-eigenaar (Amerikaans of anderszins) in de keten.
