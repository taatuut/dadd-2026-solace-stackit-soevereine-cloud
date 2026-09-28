# Lokale broker: opzet en configuratie

## Wat en waarom

Een enkele, self-managed Solace PubSub+ software broker (standard edition),
**single-availability** (geen HA-trio) omdat dit een wegwerpbare demo-omgeving
is die binnen enkele minuten opnieuw opgezet moet kunnen worden -- HA voegt
hier alleen complexiteit toe zonder de kernboodschap (soevereine routering)
te versterken. De drie cloud-brokers zijn wel HA, omdat dat past bij een
"echt" productiesysteem en bij de eis uit de opdracht.

## Status: draait

De container is gestart met `../local-broker/docker-run.sh` (container-naam
`enewable-local-broker`, image `solace/solace-pubsub-standard`). Bevestigd
via Docker Desktop en de SEMP-health-check in het script zelf:

| Endpoint | Adres |
|---|---|
| Broker Manager (SEMP) | `http://localhost:8080` (admin/admin) |
| SMF (messaging) | `tcp://localhost:55554` |
| Web messaging (stm) | `ws://localhost:8008` |
| MQTT | `tcp://localhost:1883` |
| AMQP | `amqp://localhost:5672` |

Volgende sub-stap: `../local-broker/semp/configure-local-broker.sh` draaien
om de Message VPN, client-usernames/ACL's en de 3 bridges aan te maken.

## Starten

Zie `../local-broker/docker-run.sh`. Kort samengevat:

```bash
docker run -d --name enewable-local-broker \
  --shm-size=2g --ulimit nofile=2448:1048576 \
  -p 55554:55555 -p 8080:8080 -p 8008:8008 -p 1883:1883 -p 5672:5672 -p 9000:9000 \
  --env username_admin_globalaccesslevel=admin --env username_admin_password=admin \
  solace/solace-pubsub-standard
```

SMF (het binaire messaging-protocol) wordt op hostpoort **55554** in plaats
van het standaard 55555 gepubliceerd, omdat 55555 op macOS regelmatig al in
gebruik is. Pas dit aan in `docker-run.sh` en `.env` als dat bij jou niet
nodig is.

## Configureren (Message VPN, ACL's, bridges)

Zie `../local-broker/semp/configure-local-broker.sh`. Dit script (SEMP v2 /
curl) doet, in volgorde:

1. Message VPN `enewable` aanmaken en de benodigde services (SMF,
   web-messaging voor `stm`) inschakelen. REST wordt bewust niet
   ingeschakeld -- geen van de 3 demo-apps gebruikt het, en het vereist een
   apart geconfigureerde listen-port (zie "Bekende risico's").
2. Drie client-usernames aanmaken (`pub-public`, `pub-eu-ops`, `pub-eu-pii`),
   elk met een eigen ACL-profiel dat publiceren beperkt tot precies één
   topic-subtree (zie `../docs/topologie.md`).
3. Drie bridges aanmaken (`bridge-to-aws`, `bridge-to-azure`,
   `bridge-to-stackit`), elk met een `remoteSubscription` die exact één
   topic-subtree exporteert naar de bijbehorende cloud-broker.

**macOS-gebruikers**: dit script draait met `#!/usr/bin/env bash` maar
gebruikt bewust **geen** bash associative arrays (`declare -A`) -- macOS'
systeem-`/bin/bash` is bash 3.2 (Apple heeft dit bevroren sinds El Capitan om
licentieredenen) en bash 4 is nodig voor `-A`. Bevestigd op Emils machine:
zonder `-A` faalt zoiets als `[pub-public]=...` hard onder `set -u`
("pub: unbound variable"), omdat het als een indexed-array-subscript
arithmetisch wordt geëvalueerd. Het script is inmiddels herschreven zonder
associative arrays.

## Bekende risico's / dingen om te verifiëren voor de live demo

- **SEMP-veldnamen per broker-versie**: de exacte SEMP v2-objectvelden voor
  bridges (`remoteMsgVpnLocation`, `remoteAuthenticationBasicClientUsername`,
  etc.) zijn hier gebaseerd op de huidige SEMP v2 Config API-referentie, maar
  kunnen per broker-release licht verschillen. **Test dit ruim vóór DADD**
  met de "SEMP API Browser" in Broker Manager (About-pagina) op je eigen
  broker-versie, en corrigeer het script waar nodig.
- **TLS-vertrouwen richting Solace Cloud**: bridges naar Solace Cloud
  gebruiken TLS op poort 55443 met een publiek CA-certificaat. De
  standaard-broker-image heeft doorgaans de meest gebruikelijke publieke
  CA's al vertrouwd, maar controleer dit (Broker Manager > CA Certificates)
  voordat je live gaat -- een niet-vertrouwd certificaat laat de bridge
  simpelweg "Down" blijven, wat een vervelende verrassing op het podium is.
- **Geen persistente opslag**: de container gebruikt geen bind-mount voor
  `/var/lib/solace`. Elke herstart van de container = opnieuw
  `configure-local-broker.sh` draaien. Voor herhaalde oefensessies in de
  aanloop naar DADD kan een bind-mount + periodieke config-export prettiger
  zijn (zie `PLAN.md`, "Wat ontbreekt of kan beter").
- **Geheimen in `.env`**: `local-broker/.env` bevat wachtwoorden in platte
  tekst en staat (terecht) in `.gitignore` -- controleer dat voordat je iets
  commit, en overweeg voor een publieke repo een `secrets/`-aanpak met een
  tool als `sops` of gewoon nooit de echte cloud-credentials op de gedeelde
  laptop/repo te zetten.
