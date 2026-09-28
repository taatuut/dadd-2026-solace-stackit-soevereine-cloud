# Lokale broker (Enewable)

Deze map bevat alles om de lokale, self-managed Solace PubSub+ broker
(standard/software edition, single-availability) te starten en te
configureren voor de DADD 2026-demo.

## Gebruik

1. `cp .env.example .env` en vul de placeholders in zodra de 3 Solace Cloud
   broker services bestaan (zie `../cloud-setup/`).
2. `./docker-run.sh` -- start de lokale broker in Docker.
3. `./semp/configure-local-broker.sh` -- richt de Message VPN, client-usernames,
   ACL-profielen en de 3 bridges (AWS/Azure/STACKIT) in op basis van `.env`.
4. Controleer in Broker Manager (http://localhost:8080, admin/admin) dat de 3
   bridges de status "Up" hebben voordat je gaat publiceren.

Zie `../docs/lokale-broker.md` voor de volledige toelichting en
`../docs/topologie.md` voor het overzichtsdiagram.
