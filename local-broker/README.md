# Lokale broker (Enewable)

Deze map bevat alles om de lokale, self-managed Solace PubSub+ broker
(standard/software edition, single-availability) te starten en te
configureren voor de DADD 2026-demo.

## Gebruik

1. `cp .env.example .env` en vul de placeholders in zodra de 3 Solace Cloud
   broker services bestaan (zie `../cloud-setup/`).
2. `./docker-run.sh` -- start de lokale broker in Docker.
3. `./semp/configure-local-broker.sh` -- richt de Message VPN, client-usernames
   en ACL-profielen in op basis van `.env`.
4. `./semp/configure-rdp-export.sh` -- richt de 3 export-queues en de 3
   REST Delivery Points (AWS/Azure/STACKIT) in die daadwerkelijk naar de
   cloud-brokers publiceren. Vereist dat `*_REMOTE_REST_HOST`/
   `*_REMOTE_REST_PORT` in `.env` zijn bevestigd (Connect-tab, REST-sectie).
5. Controleer in Broker Manager (http://localhost:8080, admin/admin) dat de
   3 queues berichten ontvangen en de 3 REST Delivery Points de status "Up"
   hebben voordat je gaat publiceren. Als een RDP "Down" blijft, geeft
   Broker Manager zelf geen reden -- draai `./semp/diagnose-rdp.sh`
   (read-only, schrijft naar `../output/diagnose-rdp.txt`) voor de
   SEMP v2 MONITOR-details.

Zie `../docs/lokale-broker.md` voor de volledige toelichting en
`../docs/topologie.md` voor het overzichtsdiagram.
