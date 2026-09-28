# Cloud platform brokers (Solace Cloud)

Deze map beschrijft de opzet van de drie Solace Cloud platform brokers die
samen met de lokale broker de soevereine, gedistribueerde topologie vormen:

| Map                        | Provider / regio                   | Rol in de demo                                    |
|-----------------------------|--------------------------------------|-----------------------------------------------------|
| `aws-us-east/`               | AWS, US East                         | Ontvangt PUBLIEKE data                              |
| `azure-west-europe/`         | Azure, West Europe (Nederland)       | Ontvangt niet-persoonlijke EU-data                  |
| `stackit-eu01/`               | STACKIT, Duitsland (regio `eu01`)    | Ontvangt gevoelige PII (sovereign) -- **verwacht GA komende week** |
| `gcp-europe-west1-interim/`   | GCP, België (`europe-west1`)         | **Tijdelijke stand-in** voor STACKIT, tot GA        |

De eerste drie (AWS/Azure/STACKIT) zijn de definitieve topologie; de
vierde map (`gcp-europe-west1-interim/`) is alleen nodig zolang STACKIT nog
niet algemeen beschikbaar is. Alle zijn **HA (high-availability)** Solace Cloud services: elk bestaat
uit een primary/backup broker-paar plus monitoring node, beheerd door Solace
Cloud (Mission Control). Zie `../docs/cloud-brokers.md` voor de volledige
toelichting en het belangrijke openstaande punt rond STACKIT-beschikbaarheid.

## Volgorde van werken

1. Maak (of hergebruik) een Solace Cloud account en een API-token met de
   scope `services:post`/`services:get` (Mission Control > API Tokens).
2. Maak de 3 services aan -- via de console (aanbevolen voor de eerste keer)
   of via `solace-cloud-api/create-service.sh` (REST API, herhaalbaar).
3. Noteer per service: SMF-host:port (55443, TLS), REST-host:port (9443,
   aanname -- bevestig op de Connect-tab) en Message VPN-naam (zie per
   submap; deze zijn al ingevuld in `../local-broker/.env.example`).
4. Maak per service een publish-client-username (`enewable-local-bridge` --
   de naam is historisch, dit wordt nu gebruikt door de REST Delivery
   Point's REST-consumer, niet door een bridge; wachtwoord al gegenereerd in
   `../local-broker/.env`) met een publish-only ACL-profiel -- handmatig via
   Manage > Client Usernames (zie per submap), of automatisch met
   `solace-cloud-api/configure-remote-bridge-users.sh` zodra je de
   SEMP-admin-username/password per broker (Connect-tab) in `.env` hebt
   ingevuld. **Let op**: dit script gebruikt de SEMP v2 Config API van elke
   broker zelf, niet de Mission Control API/het token -- en moet, net als
   `create-service.sh`, door jou zelf gedraaid worden (zie
   `../docs/cloud-brokers.md`, "Provisioning: console vs. API" voor waarom).
5. Run `../local-broker/semp/configure-local-broker.sh` (VPN, ACL's,
   publishers) en daarna `../local-broker/semp/configure-rdp-export.sh` (de
   3 export-queues + REST Delivery Points) om de lokale broker en de export
   naar de 3 cloud-brokers op te zetten.
