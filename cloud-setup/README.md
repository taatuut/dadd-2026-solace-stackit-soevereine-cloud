# Cloud platform brokers (Solace Cloud)

Deze map beschrijft de opzet van de drie Solace Cloud platform brokers die
samen met de lokale broker de soevereine, gedistribueerde topologie vormen:

| Map                        | Provider / regio                   | Rol in de demo                                    |
|-----------------------------|--------------------------------------|-----------------------------------------------------|
| `aws-us-east/`               | AWS, US East                         | Ontvangt PUBLIEKE data                              |
| `azure-west-europe/`         | Azure, West Europe (Nederland)       | Ontvangt niet-persoonlijke EU-data                  |
| `stackit-eu01/`               | STACKIT, Duitsland (regio `eu01`)    | Ontvangt gevoelige PII (sovereign); eigen `SolaceDedicated`-datacenter |

Dit zijn de drie Solace Cloud services die samen de topologie vormen, elk
op "Developer 100"-tier, beheerd door Solace Cloud (Mission Control). Zie
`../docs/cloud-brokers.md` voor de volledige toelichting.

De aanbevolen, herhaalbare manier om deze 3 services aan te maken is
**Terraform** ([`terraform/README.md`](terraform/README.md)): twee Solace
Cloud-organisaties (AWS+Azure in de ene, STACKIT in de andere), elk als
"Developer 100"-tier. De hieronder beschreven console-/
`create-service.sh`-route is een handmatig alternatief of fallback.

## Volgorde van werken

1. Maak (of hergebruik) een Solace Cloud account en een API-token met de
   scope `services:post`/`services:get` (Mission Control > API Tokens).
2. Maak de 3 services aan - via de console (aanbevolen voor de eerste keer)
   of via `solace-cloud-api/create-service.sh` (REST API, herhaalbaar).
3. Noteer per service: SMF-host:port (55443, TLS), REST-host:port (9443,
   aanname - bevestig op de Connect-tab) en Message VPN-naam (zie per
   submap; deze zijn al ingevuld in `../local-broker/.env.example`).
4. Maak per service een publish-client-username (`enewable-local-bridge` -
   deze naam dekt niet de huidige functie: wordt gebruikt door de REST
   Delivery Point's REST-consumer, niet door een bridge; wachtwoord al
   gegenereerd in `../local-broker/.env`) met een publish-only ACL-profiel - handmatig via
   Manage > Client Usernames (zie per submap), of automatisch met
   `solace-cloud-api/configure-remote-bridge-users.sh` zodra je de
   SEMP-admin-username/password per broker (Connect-tab, of via
   `solace-cloud-api/get-broker-manager-credentials.sh`, dat deze uit de
   Terraform-state leest) in `.env` hebt ingevuld. **Let op**:
   `configure-remote-bridge-users.sh` gebruikt de SEMP v2 Config API van
   elke broker zelf, niet de Mission Control API/het token - en moet, net
   als `create-service.sh`, door jou zelf gedraaid worden (zie
   `../docs/cloud-brokers.md`, "Provisioning: console vs. API" voor
   waarom).
5. Run `../local-broker/semp/configure-local-broker.sh` (VPN, ACL's,
   publishers) en daarna `../local-broker/semp/configure-rdp-export.sh` (de
   3 export-queues + REST Delivery Points) om de lokale broker en de export
   naar de 3 cloud-brokers op te zetten.
