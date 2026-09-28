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

## Status: aangemaakt

| Veld | Waarde |
|---|---|
| Servicenaam | `ez-dadd-2026-STACKIT-gke-gcp-europe-west1-b` |
| Cloud / regio | Google Cloud, regio-code `gke-gcp-europe-west1-b` (europe-west1, België) |
| Service class | Enterprise, 250 connecties, 50 GB message spool, HA Group |
| Broker release | 10.26 (Event Broker Service Version `10.26.0.8894-14`) |
| Service ID | `0kc8gh43pg3` |
| Service State | Running |
| Netwerktoegang | Public cluster (zie `../../docs/cloud-brokers.md`, sectie "Netwerktoegang") |
| Message VPN | `ez-dadd-2026-stackit-gke-g` (auto-gegenereerd, afgekapt op 26 tekens en lowercased) |
| SMF-hostname | `mr-connection-gp982rqw5dk.messaging.solace.cloud` |
| Cluster name | `cluster-gke-gcp-europe-west1-b-4lkzoejsoju` |
| Aangemaakt door | Emil Zegers (emil.zegers@solace.com), 28/09/2026 02:07:56 |

Screenshots van elke stap staan in
[`../../screenshots/STACKIT-of-GCP-interim/`](../../screenshots/STACKIT-of-GCP-interim/).

Zie ook [`../../docs/cloud-brokers.md`](../../docs/cloud-brokers.md),
sectie "Wat de AWS-, Azure- en GCP-interim-opzet ons hebben geleerd", voor
de bredere lessen (regio-codes, VPN-naamgeving) die bij het aanmaken van
deze service zijn bevestigd.

## Nog te doen voor deze service

1. Connect-tab openen en het exacte SMF-poortnummer bevestigen (55443/TLS
   aangenomen, net als bij AWS en Azure).
2. Onder Manage > Client Usernames een client-username aanmaken (bijv.
   `enewable-local-bridge`) met een ACL-profiel dat **alleen publiceren**
   toestaat op `enewable/eu/pii/>` -- de bridge levert hier berichten af
   als publisher, niet als subscriber.
   **Gebruik niet de standaard `solace-cloud-client`-username hiervoor** -- die wordt door de "Try Me!"-tab van deze service gebruikt om tijdens de live demo de binnenkomende berichten te laten zien, en heeft standaard een ruim ACL-profiel. Een nieuwe, dedicated username met een eigen, beperkt ACL-profiel houdt de "Try Me!"-subscriptie werkend en laat bovendien precies zien waar de demo over gaat: gegarandeerde, ACL-afgedwongen scheiding per dataklasse, niet toevallige scheiding via topic-naamgeving.
   Handmatig via de UI, of automatisch met `../solace-cloud-api/configure-remote-bridge-users.sh` (SEMP v2 Config API van deze broker zelf -- vul eerst `*_SEMP_HOST`/`*_SEMP_ADMIN_USER`/`*_SEMP_ADMIN_PASSWORD` in `../../local-broker/.env` in, te vinden op de Connect-tab; het wachtwoord voor `enewable-local-bridge` staat er al in).
3. De `STACKIT_*`-variabelen in `../../local-broker/.env` invullen met de
   client-username/wachtwoord van stap 2 (de VPN-naam en SMF-hostname staan
   al in `../../local-broker/.env.example`).
4. Zodra STACKIT GA is: de echte STACKIT eu01-service aanmaken, dezelfde
   `STACKIT_*`-variabelen bijwerken, `configure-local-broker.sh` opnieuw
   draaien, en deze interim-service afbouwen.
