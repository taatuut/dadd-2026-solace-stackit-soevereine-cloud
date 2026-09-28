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
Experiment afgesloten. (De testobjecten `bridge-from-enewable` op AWS en
`sub-aws` lokaal zijn later opgeruimd samen met de rest van de
bridge-configuratie, zie onderaan deze sectie.)

Overgebleven, wél haalbare routes op dat moment (zie `PLAN.md` sectie 13
voor de volledige afweging): de lokale broker publiek bereikbaar maken
zodat een échte reciprocal bridge per cloud-broker kan dialen, of bridges
loslaten voor de exportkant. Emil koos uiteindelijk een derde, betere optie
-- zie hieronder.

## ✅ Definitieve keuze: REST Delivery Points i.p.v. bridges voor export

Emil koos een derde optie, beter dan de twee hierboven: **native REST
Delivery Points (RDP)**, Solace's eigen feature om berichten van een lokale
queue naar een extern REST-endpoint te posten -- geen relay-app, geen
publieke bereikbaarheid van de lokale broker nodig (de RDP dialt zelf uit,
net als een bridge). De 3 demo-apps blijven **ongewijzigd** DIRECT
publiceren; Solace's "message promotion"-feature vangt een DIRECT-bericht
automatisch op in elke queue met een matchende topic-subscription, "no
special configuration required" (bevestigd via Solace's eigen
documentatie, zie `PLAN.md` sectie 13, punt 11).

Nieuw script: `../local-broker/semp/configure-rdp-export.sh`. Maakt per
topic-subtree:
1. Een durable **queue** (`q-export-public`/`q-export-eu-ops`/
   `q-export-eu-pii`) met een topic-subscription die exact die subtree
   matcht (promotie vangt de DIRECT-berichten van de demo-apps hierin op).
2. Een **REST Delivery Point** (`rdp-aws`/`rdp-azure`/`rdp-stackit`) met:
   - een **queue-binding** naar die queue, met
     `postRequestTarget: "/${topic()}"` -- Solace's REST-publish-service
     leest de topic uit het URL-pad van de POST, en `${topic()}` is
     Solace's substitution-syntax voor "de volledige originele topic", dus
     het bericht landt op de CLOUD-broker op precies dezelfde topic als
     lokaal.
   - een **rest-consumer** die naar de cloud-broker's eigen REST-endpoint
     wijst, met TLS en HTTP-basic-auth (hergebruikt de bestaande
     `enewable-local-bridge`-credentials, al publish-only ACL-gescoped per
     cloud-broker -- geen nieuwe secrets).

De SEMP v2-attribuutnamen (`restDeliveryPointName`, `postRequestTarget`,
`remoteHost`, `authenticationHttpBasicUsername`, etc.) zijn niet gegokt
maar gecrosscheckt tegen een werkende Go SEMP-client
(`github.com/koverton/semp_client`) omdat Solace's eigen CLI-documentatie
voor RDP's (Services/Managing-RDPs.htm) geen REST-attribuutnamen geeft --
zie `PLAN.md` sectie 13, punt 11 voor de volledige onderbouwing.

**Bevestigd correct (28/09/2026):** de aanname "zelfde hostname als SMF,
poort 9443" is juist -- de Connect-tab van de AWS-service toont exact
`https://mr-connection-07w9t1ah76x.messaging.solace.cloud:9443` onder
"Solace REST Messaging API".

**⛔ Vernauwd: de queue-binding faalt met HTTP 503 "Service Unavailable"**
(diagnose via `local-broker/semp/diagnose-rdp.sh`, uitgebreid met
queue-binding- en subscription-checks). Twee mogelijke oorzaken zijn
inmiddels **uitgesloten**: de REST-consumer's onderliggende TLS+http-basic-
verbinding naar elke cloud-broker is bevestigd gezond (`"up": true`,
`remoteOutgoingConnectionUpCount` == `outgoingConnectionCount`), en de
topic-subscriptie op elke queue is bevestigd aanwezig en correct
(`enewable/public/>` etc.). De verbinding komt dus tot stand, maar de
daadwerkelijke POST wordt door de doelbroker afgewezen met 503.
Vermoedelijke (nog niet bevestigde) oorzaak: de REST-incoming service
staat niet aan op de doel-Message-VPN -- net als lokaal (zie hierboven,
"Bekende risico's") is REST niet altijd standaard aan zoals SMF/
Web-messaging. Nieuw script: `cloud-setup/solace-cloud-api/
enable-rest-on-cloud-vpns.sh` (checkt en zet zo nodig
`serviceRestIncomingTlsEnabled` aan op elke cloud-VPN, via elke broker's
eigen SEMP v2 Config API). Emil moet dit zelf draaien -- deze sessie kan
`*_SEMP_HOST` niet bereiken -- en daarna `diagnose-rdp.sh` nogmaals draaien
om te checken of de queue-binding's `lastFailureReason` verandert en de
RDP op `"up": true"` komt. Niet gegarandeerd de fix: als dit niet werkt,
kijk naar andere 503-oorzaken (client-profile REST-rechten, VPN-spool/
shutdown-status). Zie `PLAN.md` sectie 13, punt 16.

**⛔ Vervolg (28/09/2026): de 503 blijft bestaan bij een derde diagnose-run.**
Alle 3 queue-bindings tonen opnieuw `"lastFailureReason": "Service
Unavailable"`, met een `lastFailureTime` die vrijwel samenvalt met het
moment van de diagnose-run zelf -- dit is dus een actuele, herhaalde
mislukking (past bij de RDP's automatische reconnect-lus), geen oude
waarde. Onduidelijk is of dit gemeten is vóór of na een run van
`enable-rest-on-cloud-vpns.sh`; als het probleem blijft bestaan terwijl
REST-incoming al aan bleek te staan, is die theorie ontkracht. Nieuw
script: `cloud-setup/solace-cloud-api/test-rest-direct.sh` -- bypasst de
RDP volledig en POST't rechtstreeks (curl, dezelfde http-basic
credentials) naar elke cloud-broker se REST-endpoint, zodat de échte
HTTP-statusregel en responsebody zichtbaar worden in plaats van de RDP se
samenvatting. Zie `PLAN.md` sectie 13, punt 17.

**✅ Doorbraak (28/09/2026): een directe curl-POST naar alle 3 cloud-brokers
lukt (`HTTP/1.1 200 OK`)**, met dezelfde host, poort, http-basic
credentials en topic-uit-pad-constructie als de RDP gebruikt. Dit sluit
REST-incoming-uitgeschakeld, verkeerde auth, host/poort en topic-mapping
definitief uit als oorzaak van de 503 -- bevestigd ook via
`enable-rest-on-cloud-vpns.sh`: op Azure stond `serviceRestIncomingTlsEnabled`
al op `true` vóórdat de PATCH liep. Belangrijke aanvullende aanwijzing: de
REST-consumer se eigen HTTP-tellers (`httpRequestTxMsgCount`,
`httpResponseSuccessRxMsgCount`, etc.) staan voor alle 3 nog op **0** -- er
is dus nog nooit een échte berichtaflevering geprobeerd. De "Service
Unavailable" op de queue-binding is daarom waarschijnlijk geen mislukte
*bericht*-aflevering, maar een RDP-interne gereedheids-/probe-stap.
**Vervolgstap:** een echte end-to-end publish-test (`demo-apps/
stm-public/publish-public.sh`), dan `diagnose-rdp.sh` opnieuw om te
checken of het bericht in de queue landt en de tellers bewegen. Zie
`PLAN.md` sectie 13, punt 18.

**⛔ Nieuw, apart probleem (28/09/2026): de lokale broker wijst
`pub-public` af.** Na het fixen van de stm CLI-syntax (zie hieronder)
loopt de publish-test meteen vast op de allereerste hop -- stm naar de
lokale broker over Web Messaging (`ws://localhost:8008`) -- met
`error: connection failed to the message router / The RADIUS profile is
shutdown - - check the connection parameters!`. Dit staat los van het
RDP/503-onderzoek hierboven: het gaat mis vóórdat er ook maar íets bij
een cloud-broker aankomt. Vermoeden: de `enewable`-VPN se
`authenticationBasicType` staat op "radius" in plaats van "internal"
(een vers aangemaakte VPN staat normaal op internal-auth;
`configure-local-broker.sh` zet dit veld nergens expliciet). Nieuw
script: `local-broker/semp/diagnose-local-auth.sh` -- checkt de VPN se
auth-type, eventuele RADIUS-profielen, het client-profile "default", en
alle 4 client-usernames se enabled-status. Moet Emil vanuit zijn eigen
terminal draaien (niet de sandbox -- die kan `localhost:8080` niet
bereiken). Zie `PLAN.md` sectie 13, punt 20.

**Gefixt (28/09/2026): `stm publish` bestaat niet.** De geïnstalleerde
Solace Try-Me CLI (v1.0.0) heeft geen `publish`-subcommando -- de juiste
is `stm send` (zelfde vlaggen). Gefixt in
`demo-apps/stm-public/publish-public.sh` en `stm-public/README.md`. Zie
`PLAN.md` sectie 13, punt 19.

**Opgeruimd (28/09/2026):** de 3 oude bridge-objecten
(`bridge-to-aws/azure/stackit`), de reciprocal-bridge-testopstelling
(`sub-aws`, `bridge-from-enewable` op AWS) en de bijbehorende scripts
(`test-reciprocal-bridge-aws.sh`, `diagnose-bridges.sh`) zijn verwijderd uit
de repo -- ze dienden geen doel meer zodra RDP's het exportpad overnamen.
Draai `configure-local-broker.sh` opnieuw op een broker waar deze objecten
nog bestaan (van een eerdere sessie) om ze daar handmatig op te ruimen; de
scripts zelf maken ze niet meer aan.

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

## Configureren (Message VPN, ACL's)

Zie `../local-broker/semp/configure-local-broker.sh`. Dit script (SEMP v2 /
curl) doet, in volgorde:

1. Message VPN `enewable` aanmaken en de benodigde services (SMF,
   web-messaging voor `stm`) inschakelen. REST wordt bewust niet
   ingeschakeld -- geen van de 3 demo-apps gebruikt het, en het vereist een
   apart geconfigureerde listen-port (zie "Bekende risico's").
2. Drie client-usernames aanmaken (`pub-public`, `pub-eu-ops`, `pub-eu-pii`),
   elk met een eigen ACL-profiel dat publiceren beperkt tot precies één
   topic-subtree (zie `../docs/topologie.md`).
(De 3 bridges die dit script eerder ook aanmaakte zijn verwijderd -- dat
bleek architecturaal niet te kunnen exporteren zonder reciprocal bridge +
publieke bereikbaarheid, zie hieronder.)

Het **daadwerkelijke** exportpad loopt via
`../local-broker/semp/configure-rdp-export.sh` (los script, ná
`configure-local-broker.sh` te draaien): 3 queues + 3 REST Delivery Points,
zie "✅ Definitieve keuze" hieronder.

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
- **REST-host/poort per cloud-service niet bevestigd**: `*_REMOTE_REST_HOST`
  gebruikt dezelfde hostname als de SMF-verbinding, `*_REMOTE_REST_PORT` is
  aangenomen als 9443 (Solace Cloud's standaard secure-REST-poort) -- dit is
  een aanname, niet bevestigd tegen de Connect-tab. Controleer dit vóór het
  draaien van `configure-rdp-export.sh`, en zet REST-messaging aan voor die
  service als het nog uit staat.
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
