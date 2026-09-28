# GCP Belgium / europe-west1 -- tijdelijke stand-in voor STACKIT eu01

**Dit is geen permanent onderdeel van de topologie.** Deze service mimickt
de sovereign/PII-bestemming totdat STACKIT algemeen beschikbaar is in Solace
Cloud (verwacht: komende week). Zie
[`../stackit-eu01/README.md`](../stackit-eu01/README.md) voor de definitieve
opzet en de overstap zodra STACKIT GA is.

> Let op voor de presentatie: dit knooppunt is bewust **niet** sovereign
> (GCP is een Amerikaanse hyperscaler) -- benoem dit expliciet als je deze
> interim-opzet tijdens een oefensessie of vroege demo gebruikt, zodat het
> publiek niet denkt dat de PII-data al naar een soevereine omgeving gaat.
> Voor de uiteindelijke DADD-presentatie zelf is het uitgangspunt dat STACKIT
> dan al de echte bestemming is.

## Aanmaken (Solace Cloud console)

Volg dezelfde stappen als bij AWS US East (zie
[`../aws-us-east/README.md`](../aws-us-east/README.md)) voor consistentie:

1. Solace Cloud > Cluster Manager > **+ Create Service**.
2. Cloud provider: **GCP**, regio: **europe-west1 (België)** -- zoek de
   exacte Solace-regio-code op in de Region-dropdown (bij AWS bleek dit
   bijvoorbeeld `eks-us-east-1a` te zijn, niet de kale providernaam).
3. Service class: **Enterprise**, 250 connecties, HA Group -- zelfde als AWS.
4. Servicenaam: `ez-dadd-2026-gcp-europe-west1-interim` (of vergelijkbaar).
5. Message VPN: laat auto-genereren of zet 'm handmatig; hoeft niet
   "enewable" te zijn (zie `../../docs/cloud-brokers.md`).
6. Maak screenshots van elke stap in
   `../../screenshots/STACKIT-of-GCP-interim/`, net als bij AWS.

Alternatief via API: `../solace-cloud-api/create-service.sh
ez-dadd-2026-gcp-europe-west1-interim <datacenterId-voor-gcp-europe-west1>
ENTERPRISE_250_HIGHAVAILABILITY`.

## Na het aanmaken

1. Noteer SMF-host:port (TLS, verwacht 55443) via de Connect-tab, en de
   werkelijke Message VPN-naam.
2. Maak een client-username (bijv. `enewable-local-bridge`) met een
   ACL-profiel dat **alleen publiceren** toestaat op `enewable/eu/pii/>` --
   identiek aan wat je straks bij de echte STACKIT-service doet (de bridge
   levert hier berichten af als publisher, niet als subscriber).
3. Vul de `STACKIT_*`-variabelen in `../../local-broker/.env` met de
   gegevens van *deze* interim-service (de variabelenamen blijven
   `STACKIT_*` omdat dat de uiteindelijke, definitieve bestemming
   beschrijft; alleen de waarden zijn tijdelijk).
4. Zodra STACKIT GA is: maak de echte STACKIT eu01-service aan, vervang de
   waarden van dezelfde `STACKIT_*`-variabelen, herconfigureer de bridge
   (`configure-local-broker.sh` opnieuw draaien is voldoende), en trek deze
   interim-service in.
