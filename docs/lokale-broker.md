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
| Broker-versie | `10.25.0.208` (bevestigd via Broker Manager) |

Message VPN `enewable` bestaat al (Status: Up) -- aangemaakt door de eerste,
deels geslaagde run van `configure-local-broker.sh` (de VPN-POST liep door
vóór de REST-PATCH die faalde). De hernieuwde run van het script slaat dit
gewoon over ("already exists") en gaat door met de client-usernames en
bridges.

`../local-broker/semp/configure-local-broker.sh` is inmiddels meerdere keren
gedraaid en draait nu volledig schoon (0 WARN-regels): VPN, ACL's,
client-usernames en alle 3 bridge-objecten + hun `remoteMsgVpns`/
`remoteSubscriptions` worden zonder SEMP-fout aangemaakt. Bevestigd via
screenshots van Broker Manager > Bridges > Summary: elke bridge toont nu de
juiste remote Message VPN-naam en `via: <ip>:55443`, dus de configuratie komt
aan bij de broker. **Toch bleven alle 3 bridges "Down"** (Bridge Status, en
Message Flow in beide richtingen) -- ondanks dat `diagnose-bridges.sh` liet
zien dat de onderliggende verbinding zelf prima werkte:
`remoteMsgVpns[].up: true`, `lastConnectionFailureReason: ""`,
`rxConnectionFailureCategory: "no-failure"`, uptime > 900s, TLS + basic-auth
allebei geslaagd (`remoteRouterName` kwam terug van de cloud-broker). Geen
verbindingsfout dus, maar het bridge-object had wel
`inboundState: "ready-subscribing"` / `outboundState: "not-applicable"`.

**❗ Open architectuurpunt (niet langer een scriptbug, maar een fundamentele
richtingskwestie in hoe Solace-bridges werken):** een bridge's
**`remoteSubscription`** (het enige dat een bridge op de LOKALE broker kan
configureren) trekt berichten van de REMOTE broker NAAR BINNEN -- import, niet
export. Een eerste poging om dit te fixen met een verondersteld
`localSubscription`-sub-object bleek onjuist: dat bestaat niet voor bridges
(bevestigd door zowel de broker zelf -- de bridge-links in SEMP noemen alleen
`remoteMsgVpnsUri`/`remoteSubscriptionsUri`/`tlsTrustedCommonNamesUri`/`uri`
-- als door Solace's eigen documentatie). Volgens die documentatie is de
enige manier om berichten die lokaal gepubliceerd worden over een bridge naar
een remote VPN te exporteren: **een tweede, wederkerige bridge**, dit keer
geconfigureerd OP de cloud-broker zelf, met "enewable" (lokaal) als *diens*
remote VPN en een `remoteSubscriptionTopic` die overeenkomt met de
gewenste topic-subtree. Zo'n bridge wordt door de cloud-broker actief
OPGEZET NAAR ONZE lokale broker toe -- wat betekent dat de lokale broker's
SMF-poort **vanaf het publieke internet bereikbaar** moet zijn (nu alleen
`localhost:55554`). Dat is een netwerk-/infrastructuurbeslissing, niet iets
wat met een scriptfix op te lossen is -- zie `PLAN.md`, sectie 13, voor de
opties (tunnel, port-forwarding, of de lokale broker op een cloud-VM in
plaats van Emils laptop) en de vraag die daar aan Emil is voorgelegd.

**Update: er loopt nu een experiment vóór we naar de zwaardere
netwerkoplossingen grijpen.** Solace's documentatie beschrijft een
"bi-directional bridge"-modus waarbij de kant die met een IP/FQDN verbindt
(onze bestaande, al werkende `bridge-to-aws`) de connectie opent, en de
ANDERE kant -- geconfigureerd met de peer's **virtual router-name**
(`v:<naam>`) i.p.v. een adres -- die bestaande connectie "discovert" in
plaats van zelf een nieuwe te openen. Als dat ook geldt voor een kale
Message-VPN-bridge (niet bevestigd of dit een DMR-cluster vereist), hoeft de
lokale broker niet publiek bereikbaar te zijn.

Getest met alleen AWS (om goedkoop te falen als het niet werkt):
1. Lokale broker's eigen virtual router-name opgevraagd via legacy SEMP:
   `curl -u admin:admin -H "Content-Type: application/xml" -d '<rpc><show><router-name></router-name></show></rpc>' http://localhost:8080/SEMP`
   -- resultaat: `3a106d66a729` (de Docker-container-hostname), vastgelegd
   als `LOCAL_ROUTER_NAME` in `.env`.
2. `configure-local-broker.sh` sectie 4 (nieuw): maakt `sub-aws` aan, een
   subscribe-only client-username op de LOKALE broker (ACL: uitsluitend
   subscriben op `enewable/public/>`), voor de reciprocal bridge om mee in
   te loggen.
3. `../cloud-setup/solace-cloud-api/test-reciprocal-bridge-aws.sh` (nieuw):
   maakt, via AWS's eigen SEMP-admin, een bridge `bridge-from-enewable` OP
   AWS aan met `remoteMsgVpnLocation` = `v:3a106d66a729`.

**Uitkomst: negatief.** Na het draaien van beide scripts toont
`bridge-from-enewable` op AWS "Down", Establisher "N/A" -- AWS heeft niet
eens geprobeerd `v:3a106d66a729` te resolven. Onze lokale `bridge-to-aws`
bleef ook onveranderd. De router-name-discovery uit Solace's
bi-directional-bridge-documentatie werkt dus niet voor een kale
Message-VPN-bridge zonder DMR-cluster-lidmaatschap tussen de twee brokers --
dat opzetten is een te groot traject voor de resterende tijd tot DADD.
Experiment afgesloten; de testobjecten (`bridge-from-enewable` op AWS,
`sub-aws` lokaal) blijven onschadelijk staan.

Overgebleven, wél haalbare routes (zie `PLAN.md` sectie 13 voor de volledige
afweging): de lokale broker publiek bereikbaar maken zodat een échte
reciprocal bridge per cloud-broker kan dialen, of bridges loslaten voor de
exportkant en een lokale relay-app bouwen die zelf, als gewone client, van
lokaal naar elke cloud-broker publiceert. De bestaande 3 bridges
(`bridge-to-aws` e.a.) blijven ongewijzigd staan (niet schadelijk) tot een
van deze twee gekozen is. Broker Manager toont zelf geen down-reden;
`../local-broker/semp/diagnose-bridges.sh` (schrijft naar
`output/diagnose-bridges.txt`, gitignored) blijft nuttig om dit soort
dingen te verifiëren i.p.v. te gokken -- zoals hier ook gebeurd is.

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
  simpelweg "Down" blijven. **Dit risico is nu actueel**: na een volledig
  schone `configure-local-broker.sh`-run blijven alle 3 bridges toch "Down"
  -- zie "Status: draait" hierboven en `diagnose-bridges.sh` voor de
  vervolgstap om de exacte oorzaak (TLS, netwerk, of credentials) vast te
  stellen in plaats van te gokken.
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
