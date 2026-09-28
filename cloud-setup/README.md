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
3. Noteer per service: SMF-host:port (55443, TLS), Message VPN-naam, en maak
   een client-username aan die de lokale bridge mag gebruiken om te
   verbinden (zie per submap).
4. Vul die gegevens in `../local-broker/.env` in en run
   `../local-broker/semp/configure-local-broker.sh`.
