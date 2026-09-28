# DADD 2026 -- Solace / STACKIT: soevereine cloud-demo (Enewable)

Demo-project bij de presentatie **"Ontwerpen voor soevereiniteit: de
verborgen kosten van het verlaten van de hyperscalers"** van Emil Zegers,
DADD 2026.

Vier Solace-brokers (1 lokaal, self-managed + 3 Solace Cloud HA-services in
AWS/Azure/STACKIT), verbonden via REST Delivery Points (RDP's), die laten
zien hoe data op basis
van classificatie (publiek / niet-persoonlijk EU / gevoelige PII)
automatisch naar precies de juiste, en alleen de juiste, bestemming
stroomt.

**Begin hier: [`PLAN.md`](PLAN.md)** -- het complete plan van aanpak, met
topologie, opzet per broker, demo-apps, draaiboek en openstaande punten.

## Snelstart (na het lezen van PLAN.md)

```bash
cd local-broker
cp .env.example .env        # vul in na het aanmaken van de cloud-brokers
./docker-run.sh
./semp/configure-local-broker.sh
```

Zie de map [`docs/`](docs/) voor de uitgewerkte documentatie per onderdeel,
en [`demo-apps/`](demo-apps/) voor de drie databronnen (stm / Python /
SDKPerf).

## Taal

Documentatie (`PLAN.md`, `docs/`) is in het Nederlands. Code en
configuratie (scripts, JSON, commentaar daarin) is in het Engels, conform
gangbare praktijk voor techniek/config.
