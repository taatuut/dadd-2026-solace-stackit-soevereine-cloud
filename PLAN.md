# Plan van aanpak -- DADD 2026 demo: soevereine, event-driven infrastructuur (Enewable)

Bij de presentatie **"Ontwerpen voor soevereiniteit: de verborgen kosten van
het verlaten van de hyperscalers"** van Emil Zegers, DADD 2026
([sessie-overzicht](https://dadd.nl/index.php/sessies-dadd-2026/)).

Status: in uitvoering, stap voor stap (zie voortgangstabel hieronder). Dit
document wordt na elke stap bijgewerkt met wat er echt is gebeurd -- niet
alleen wat gepland was.

## Voortgangsstatus

| Onderdeel | Status | Details |
|---|---|---|
| Fase 1 -- STACKIT-beschikbaarheid | Interim actief | Uitgangspunt: STACKIT GA komende week; tot dan interim-broker op GCP europe-west1, zie fase 3 |
| Fase 2 -- Solace Cloud account/token | ✅ Gereed | API-token `dadd-2026` aangemaakt (alle permissies); staat in `token-dadd-2026.txt` (genegeerd door git) |
| Fase 3 -- AWS US East | ✅ Aangemaakt | Service `ez-dadd-2026-eks-us-east-1a`, zie [`cloud-setup/aws-us-east/README.md`](cloud-setup/aws-us-east/README.md) en `screenshots/AWS/` |
| Fase 3 -- Azure West Europe | ✅ Aangemaakt | Service `ez-dadd-2026-aks-westeurope`, zie [`cloud-setup/azure-west-europe/README.md`](cloud-setup/azure-west-europe/README.md) en `screenshots/Azure/` |
| Fase 3 -- STACKIT / GCP-interim | ✅ Aangemaakt | Service `ez-dadd-2026-STACKIT-gke-gcp-europe-west1-b` (interim op GCP europe-west1), zie [`cloud-setup/gcp-europe-west1-interim/README.md`](cloud-setup/gcp-europe-west1-interim/README.md) en `screenshots/STACKIT-of-GCP-interim/` -- alle 3 cloud-broker services zijn nu aangemaakt |
| Fase 4 -- Lokale broker + RDP-export | ✅✅ VOLLEDIG WERKEND, end-to-end bevestigd | Na de rdp-deliver-profiel-fix: alle 3 queue-bindings up:true met bindSuccessCount:1, RDP-aws leverde daadwerkelijk 21 berichten af (httpResponseSuccessRxMsgCount:21) en AWS "Try Me!" toont het echte bericht aankomen op enewable/public/market/price. Zie PLAN.md sectie 13, punt 28. Klaar voor volledige testronde (fase 5) |
| Fase 5 -- Demo-apps valideren | ✅✅ 3/3 geslaagd | stm-public (AWS) ✅, python-eu-nonpersonal (Azure) ✅ (na een zsh-commentaar-instructiefout, zie sectie 13 punt 29), sdkperf-pii (STACKIT) ✅ (na een SDKPERF_BIN-fix, zie sectie 13 punt 30) -- volledige testronde afgerond, elke app landt uitsluitend op zijn eigen doelbroker |
| Fase 6 -- Draaiboek + fallback | Nog te doen | |

## Inhoud

1. Context en doelstelling
2. Scenario: Enewable
3. Topologie (verwijzing)
4. Architectuurkeuzes en aannames
5. Lokale broker (verwijzing)
6. Cloud platform brokers (verwijzing)
7. Demo-apps (verwijzing)
8. Beveiliging en governance
9. Repo-structuur
10. Fasering / stappenplan
11. Draaiboek voor de live demo
12. Testplan / verificatie
13. Wat ontbreekt of beter kan
14. Vervolgstappen

---

## 1. Context en doelstelling

De presentatie betoogt dat soevereiniteit niet primair een opslagvraagstuk is
("waar staat de data") maar een **bewegingsvraagstuk** ("wat kost het om
data te verplaatsen, en onder welke voorwaarden mag dat"). Egress bij
hyperscalers is 5-10x duurder dan bij Europese aanbieders, en event-driven
architectuur (alleen deltas versturen, geclassificeerd en gefilterd vóór ze
een grens oversteken) draait die rekensom om -- geschat 80-95% minder
cross-boundary verkeer.

Deze demo moet dat verhaal **letterlijk zichtbaar** maken: een gedistribueerde
topologie van vier Solace-brokers waarin data, puur op basis van zijn
classificatie, automatisch en gegarandeerd naar de juiste (en alleen de
juiste) bestemming stroomt -- en dat binnen enkele minuten op te zetten is
voor een podium-demo.

Concreet moet de demo laten zien:

- Publieke data die vrij naar een Amerikaanse hyperscaler-regio mag (AWS).
- Niet-persoonlijke data die wel binnen de EU moet blijven (Azure, Nederland).
- Gevoelige persoonsgegevens die uitsluitend naar een soeverein, Europees,
  niet-hyperscaler-platform mogen (STACKIT, Duitsland).
- Dat deze scheiding een **architecturale garantie** is (topic-gescoped
  bridges + ACL's), niet een kwestie van vertrouwen of discipline van de
  ontwikkelaar.

## 2. Scenario: Enewable

**Enewable** is een fictieve, nieuwe Nederlandse energieleverancier. Drie
soorten data, met toenemende gevoeligheid:

| Klasse | Voorbeeld | Waarom deze classificatie |
|---|---|---|
| Publiek | Day-ahead energieprijzen, publieke weerdata | Geen concurrentie- of privacygevoeligheid; vrij te delen |
| Niet-persoonlijk, EU | Geaggregeerde netbelasting per postcodegebied | Operationeel/EU-gebonden, maar niet tot een individu herleidbaar |
| Gevoelige PII | Individuele slimme-meterstand + klant-ID, facturatie | Persoonsgegeven, valt onder AVG/GDPR, hoogste bescherming |

Alle voorbeelddata in de demo-apps is **gesynthetiseerd** (nep-klant-ID's,
willekeurige waarden) -- er wordt nooit echte persoonsdata gebruikt.

## 3. Topologie

Zie [`docs/topologie.md`](docs/topologie.md) voor het volledige diagram, de
brokertabel en de topic-taxonomie. Kort samengevat: lokaal → 3 queues +
REST Delivery Points → 3 cloud-brokers, 1 topic-subtree per RDP, geen
overlap.

## 4. Architectuurkeuzes en aannames

- **Bridges, niet DMR/`#noexport`.** De opdracht vraagt expliciet om
  "bridges"; dit is functioneel voldoende om de kernboodschap te tonen
  (data buiten zijn subtree kan een bridge niet verlaten), maar is
  architecturaal een ander mechanisme dan het `#noexport`-concept uit de
  presentatie (dat werkt over Dynamic Message Routing tussen geclusterde
  brokers). Zie sectie 13.
- **Eigen client-username per dataklasse**, met ACL-profiel dat publiceren
  beperkt tot exact één topic-subtree -- dit is de "governed sharing"
  gedachte (slide 19 van de deck) toegepast op de publicatiekant. Voor de
  bridge-kant op elke cloud-broker geldt hetzelfde principe: een nieuwe,
  dedicated client-username (niet de standaard `solace-cloud-client`, die
  de "Try Me!"-tab gebruikt en een ruim ACL-profiel heeft), met een
  ACL-profiel dat alleen publiceren op de juiste topic-subtree toestaat.
  Zie `docs/cloud-brokers.md`, sectie "Credentials".
- **Single-availability lokale broker**, HA cloud-brokers -- zie
  [`docs/lokale-broker.md`](docs/lokale-broker.md) voor de afweging.
- **Solace Cloud console als primaire weg** om de 3 cloud-services aan te
  maken, met een REST API-script als optioneel alternatief -- zie
  [`docs/cloud-brokers.md`](docs/cloud-brokers.md).
- **STACKIT-broker: uitgangspunt is GA komende week**, met dezelfde
  self-service deployment als AWS/Azure/GCP -- zie
  [`cloud-setup/stackit-eu01/README.md`](cloud-setup/stackit-eu01/README.md).
  Tot het zover is, mimicken we het sovereign-knooppunt met een Solace Cloud
  HA-service op **GCP, europe-west1 (België)** -- zie
  [`cloud-setup/gcp-europe-west1-interim/README.md`](cloud-setup/gcp-europe-west1-interim/README.md).
  Topics, ACL's en bridge-naam blijven ongewijzigd bij de overstap. Zie
  sectie 10, fase 1 en fase 3.
- **Alle cloud-broker services staan in public clusters** (gekozen voor
  gemak/snelheid van de demo-opzet). In een real-life inrichting zouden
  dit private clusters zijn met verdergaande netwerkbeveiliging (VPC
  peering, PrivateLink, of vergelijkbaar) tussen de lokale broker en de
  cloud-brokers, in plaats van bridges die over het publieke internet
  lopen. Zie sectie 8 en sectie 13.
- **Geen echte persoonsgegevens**, ook niet gefingeerd op een manier die op
  een bestaande persoon zou kunnen lijken.

## 5. Lokale broker

Zie [`docs/lokale-broker.md`](docs/lokale-broker.md) en
[`local-broker/`](local-broker/) (docker-run.sh, SEMP-configuratiescript,
`.env.example`).

## 6. Cloud platform brokers

Zie [`docs/cloud-brokers.md`](docs/cloud-brokers.md) en
[`cloud-setup/`](cloud-setup/) (per-provider README's + optioneel
API-script).

## 7. Demo-apps

Zie [`docs/demo-apps.md`](docs/demo-apps.md) en [`demo-apps/`](demo-apps/)
(stm / Python / SDKPerf, elk met eigen topic-subtree en client-username).

## 8. Beveiliging en governance

- **ACL-profielen** per publisher: elke demo-app kan fysiek alleen op zijn
  eigen topic-subtree publiceren (zie `local-broker/semp/configure-local-broker.sh`).
- **TLS** op alle bridge-verbindingen naar de cloud-brokers (poort 55443).
- **Netwerktoegang cloud-brokers: public clusters, niet private/VPC-
  gepeerd.** Bewust voor demo-snelheid; in productie zou je de bridges
  laten lopen over private connectivity (VPC peering, PrivateLink of
  gelijkwaardig) in plaats van over het publieke internet met TLS +
  wachtwoord-auth alleen. Zie sectie 13.
- **Geen geheimen in git**: alle `.env`-bestanden staan (al) in `.gitignore`;
  alleen `.env.example`-bestanden met placeholders worden gecommit.
- **Topic-namen zelf zijn niet gevoelig** in deze demo (`enewable/eu/pii/...`
  verraadt weliswaar de classificatie, maar geen individuele identiteit) --
  in een productiesysteem zou je, conform slide 15 van de deck, ook
  nadenken over of topic/queue-namen zelf gevoelige metadata lekken.
- **Geen productie-credentials of -klantdata** worden ooit in deze repo of
  demo gebruikt.

## 9. Repo-structuur

```
.
|-- PLAN.md                        <- dit document
|-- README.md
|-- token-dadd-2026.txt             <- Solace Cloud API-token (gitignored, niet in repo-historie)
|-- docs/
|   |-- topologie.md
|   |-- lokale-broker.md
|   |-- cloud-brokers.md
|   |-- demo-apps.md
|   `-- Plan-van-aanpak-DADD2026-Enewable.docx   <- Word-samenvatting
|-- screenshots/                    <- bewijs/documentatie van elke aanmaak-stap
|   |-- AWS/                       (ez-dadd-2026-eks-us-east-1a)
|   |-- Azure/                     (ez-dadd-2026-aks-westeurope)
|   `-- STACKIT-of-GCP-interim/     (ez-dadd-2026-STACKIT-gke-gcp-europe-west1-b)
|-- topology/
|   `-- topologie.mmd              <- Mermaid-brondiagram
|-- local-broker/
|   |-- docker-run.sh
|   |-- .env.example
|   |-- README.md
|   `-- semp/
|       |-- configure-local-broker.sh
|       |-- configure-rdp-export.sh          <- queues + REST Delivery Points voor export naar cloud-brokers
|       |-- diagnose-rdp.sh                  <- read-only: SEMP monitor-data om RDP down-reden te vinden
|       `-- diagnose-local-auth.sh           <- read-only: VPN-auth-type + client-username-status (lokaal)
|-- cloud-setup/solace-cloud-api/
|       |-- enable-rest-on-cloud-vpns.sh     <- checkt/zet serviceRestIncomingTlsEnabled aan op elke cloud-VPN
|       `-- test-rest-direct.sh              <- bypasst de RDP, POST't rechtstreeks naar elke cloud-broker (curl)
|-- cloud-setup/
|   |-- README.md
|   |-- aws-us-east/README.md
|   |-- azure-west-europe/README.md
|   |-- stackit-eu01/README.md
|   |-- gcp-europe-west1-interim/README.md
|   `-- solace-cloud-api/
|       |-- create-service.sh
|       |-- configure-remote-bridge-users.sh   <- creates publish client-usernames + ACL's on the 3 cloud brokers (now consumed by the RDP's REST-consumer)
|       `-- .env.example
`-- demo-apps/
    |-- README.md
    |-- stm-public/
    |   |-- README.md
    |   |-- publish-public.sh
    |   `-- sample-payload.json
    |-- python-eu-nonpersonal/
    |   |-- README.md
    |   |-- publisher.py
    |   |-- requirements.txt
    |   `-- .env.example
    `-- sdkperf-pii/
        |-- README.md
        |-- publish-pii.sh
        `-- sample-payload.json
```

(`.env`-bestanden en `token-dadd-2026.txt` staan in `.gitignore` en worden
nooit gecommit -- alleen `.env.example`-bestanden zitten in de repo.)

## 10. Fasering / stappenplan

| Fase | Wat | Actie | Wanneer (t.o.v. DADD 2026) |
|---|---|---|---|
| 0 | Dit plan | Reviewen, akkoord geven of bijsturen | Nu |
| 1 | STACKIT-beschikbaarheid | ✅ Interim-broker op GCP europe-west1 (België) aangemaakt als stand-in; vlak vóór repetitie/DADD controleren of STACKIT al als datacenter-optie zichtbaar is en zo ja, overstappen | Interim: gereed; overstap-check: kort vóór fase 5/6 |
| 2 | Solace Cloud account | Account + API-token aanmaken (indien nog niet aanwezig) | Week na fase 0 |
| 3 | Cloud-brokers aanmaken | ✅ Alle 3 gereed: AWS (`ez-dadd-2026-eks-us-east-1a`), Azure (`ez-dadd-2026-aks-westeurope`), STACKIT/GCP-interim (`ez-dadd-2026-STACKIT-gke-gcp-europe-west1-b`); sovereign-node blijft STACKIT zodra GA, tot dan GCP europe-west1 interim | Gereed |
| 4 | Lokale broker + RDP-export | ✅✅ Volledig werkend, end-to-end bevestigd op alle 3 cloud-brokers (AWS, Azure, STACKIT/GCP-interim) | Fase 5 afgerond: volledige testronde met alle 3 demo-apps (stm/python/sdkperf) op alle 3 topic-subtrees, 3/3 geslaagd. Volgende: sectie 14, stap 6 (draaiboek + fallback-opname) |
| 5 | Demo-apps valideren | ✅✅ Alle 3 demo-apps bevestigd (stm-public/AWS, python-eu-nonpersonal/Azure, sdkperf-pii/STACKIT), elk uitsluitend op de eigen doelbroker | Herhalen vóór DADD zelf als extra zekerheid, niet pas op de dag zelf |
| 6 | Draaiboek + fallback-opname | Live-timing oefenen, schermopname als fallback maken | Week vóór DADD |
| 7 | Op de dag zelf | `docker-run.sh` + `configure-local-broker.sh` (of al draaiend laten staan), demo-apps klaarzetten | Vlak voor het slot |

## 11. Draaiboek voor de live demo

Zie [`docs/demo-apps.md`](docs/demo-apps.md), sectie "Voorgesteld draaiboek".
Kernpunt: drie Solace Cloud "Try Me!"-tabs (AWS/Azure/STACKIT) zichtbaar
naast elkaar, zodat het publiek in real-time ziet dat elke dataklasse
uitsluitend op zijn eigen broker verschijnt.

## 12. Testplan / verificatie

Vast controlelijstje, uit te voeren na elke wijziging aan RDP- of
ACL-configuratie, en sowieso nog een keer vlak voor DADD:

1. Alle 3 queues (`q-export-*`) ontvangen berichten en alle 3 REST Delivery
   Points (`rdp-*`) tonen "Up" in Broker Manager van de lokale broker.
2. `stm-public/publish-public.sh` → bericht verschijnt **alleen** op AWS.
3. `python-eu-nonpersonal/publisher.py` → bericht verschijnt **alleen** op Azure.
4. `sdkperf-pii/publish-pii.sh` → bericht verschijnt **alleen** op STACKIT.
5. Herhaal 2-4 maar publiceer bewust op de "verkeerde" client-username voor
   een topic (bijv. `pub-public` proberen te laten publiceren op
   `enewable/eu/pii/...`) → dit moet door de ACL geweigerd worden (negative
   test, laat de governance-garantie zien, niet alleen de happy path).
6. Herstart de lokale broker-container en herhaal `configure-local-broker.sh`
   + `configure-rdp-export.sh` → opnieuw idempotent te draaien zonder
   handmatige opschoning.
7. Meet de tijd van "koude start" (docker run tot alle 3 RDP's Up) -- moet
   ruim binnen de gewenste ~5 minuten passen; zo niet, overweeg de
   cloud-brokers al vooraf "warm" te laten draaien en alleen de lokale
   broker + RDP's als het live-onderdeel te zien.

## 13. Wat ontbreekt of beter kan

Expliciet, zoals gevraagd -- dit is een eerste plan/scaffold, geen
productieklaar systeem:

- **STACKIT GA-timing is een restrisico, niet meer de kernonzekerheid.**
  Uitgangspunt is nu dat STACKIT komende week algemeen beschikbaar is met
  dezelfde self-service flow als AWS/Azure/GCP (zie sectie 4 en 10, fase 1).
  Mocht die planning schuiven, dan draait de demo gewoon door op de
  GCP-europe-west1-interim-broker (zie
  `cloud-setup/gcp-europe-west1-interim/README.md`) -- controleer dit kort
  vóór de repetitie/DADD zelf, niet pas op de dag zelf.
- **Public clusters in plaats van private/VPC-gepeerd.** Alle drie (straks
  vier) cloud-broker services zijn bewust in public clusters aangemaakt,
  puur voor het gemak en de snelheid van deze demo-opzet. Een real-life
  inrichting van deze architectuur zou private clusters gebruiken met
  verdergaande netwerkbeveiliging tussen lokale en cloud-brokers (VPC
  peering, AWS/Azure PrivateLink of het STACKIT-equivalent), zodat het
  verkeer nooit het publieke internet op hoeft, zelfs niet met TLS.
  **Benoem dit expliciet in de presentatie/demo** als bewuste
  vereenvoudiging, niet als aanbevolen productiepatroon.
- **`#noexport`/DMR versus bridges**: voor een architecturaal preciezere
  weergave van slide 18 van de deck zou je de 4 brokers in een DMR-cluster
  kunnen zetten en PII-topics letterlijk taggen met `#noexport`, in plaats
  van (of aanvullend op) topic-gescoped bridges. Dat is een groter, minder
  demo-vriendelijk project (DMR-clustering tussen zelf-beheerde en
  Solace Cloud-brokers heeft eigen restricties) en is bewust buiten scope
  gehouden voor deze eerste versie.
- **SEMP-scriptvalidatie**: de bridge/ACL-configuratiescripts zijn
  gebaseerd op de huidige SEMP v2-documentatie maar niet getest tegen een
  live broker in deze sessie (geen broker-toegang vanuit hier) -- test dit
  als eerste concrete vervolgstap (zie sectie 14).
- **Geen netwerktoegang vanuit deze sessie tot Solace Cloud, bevestigd door
  te testen (niet aangenomen).** Zowel de Mission Control API
  (`api.solace.cloud`) als de SEMP v2 Config API van elke individuele
  broker (`mr-connection-*.messaging.solace.cloud:943`) zijn geblokkeerd
  door een organisatiebrede proxy-allowlist, zowel vanuit de cloud-container
  als vanuit de sandbox-VM op je Mac. Elk script dat een van deze twee
  aanroept (`create-service.sh`,
  `configure-remote-bridge-users.sh`) moet daarom door jouzelf gedraaid
  worden, in je eigen terminal.
- **Bash-onveilige `<...>`-placeholders in `.env`-bestanden gevonden en
  gecorrigeerd.** `local-broker/.env` en `.env.example` (en
  `cloud-setup/solace-cloud-api/.env.example`) worden met `source`
  ingelezen door de shellscripts; een niet-ingevulde placeholder als
  `<host>:943` breekt daar op (bash interpreteert `<` als
  input-redirectie). Alle placeholders zijn nu `CHANGEME_...`-stijl
  (bash-veilig, geen haakjes).
- **Scheme-verdubbelingsbug in `configure-remote-bridge-users.sh` gevonden
  en gecorrigeerd** na de eerste echte testrun door Emil: het script voegde
  altijd zelf `https://` toe, terwijl `*_SEMP_HOST` in `.env` het (redelijk,
  gezien de Connect-tab) al met `https://` was ingevuld, wat een dubbel
  scheme opleverde (`curl: Could not resolve host: https`). Het script
  accepteert de host nu met of zonder scheme-prefix.
- **`configure-local-broker.sh` faalde op macOS met 2 bugs, beide gevonden
  via Emils eerste echte testrun en gecorrigeerd**:
  1. `declare -A` (bash associative arrays) werkt niet op macOS' systeem-bash
     (`/bin/bash` is daar nog bash 3.2, bevroren sinds El Capitan om
     licentieredenen -- bash 4 is nodig voor `-A`). Zonder `-A` werd
     `[pub-public]=...` als een *indexed*-array-subscript gelezen en
     arithmetisch geëvalueerd, wat onder `set -u` hard faalt
     ("pub: unbound variable"). Herschreven zonder associative arrays, in
     dezelfde ontrolde stijl als de bestaande `create_bridge()`-aanroepen.
  2. `serviceRestIncomingPlainTextEnabled:true` op de Message VPN gaf SEMP-
     fout 89 ("A listen port must be configured first"). REST wordt door
     geen van de 3 demo-apps gebruikt (stm: web-messaging, Python/SDKPerf:
     SMF) -- verwijderd in plaats van een ongebruikte listen-port erbij te
     configureren.
  3. Bridge-aanmaak (`POST /msgVpns/{vpn}/bridges`) gaf SEMP-fout 228
     ("Expecting value for required attribute bridgeVirtualRouter") --
     bevestigt de eerder genoemde "SEMP-scriptvalidatie"-risico
     (broker-versie 10.25.0.208 vereist dit veld expliciet bij aanmaak).
     Toegevoegd: `"bridgeVirtualRouter":"auto"` (correct voor deze
     single-node, niet-redundante lokale broker -- relevant onderscheid is
     alleen primary/backup bij een HA-broker-paar). Ook de "already
     exists"-detectie in het script verbreed naar `status: ALREADY_EXISTS`
     (niet alleen `code: 6001`), zodat een herhaalde VPN-aanmaak netjes
     wordt overgeslagen in plaats van als WARN te verschijnen.
  4. Met `bridgeVirtualRouter` gefixt werd de bridge zelf wel aangemaakt,
     maar gaven `POST .../bridges/{naam}/remoteMsgVpns` en
     `.../remoteSubscriptions` beide `535 INVALID_PATH` ("No paths found").
     Oorzaak: een bridge wordt in SEMP v2 geïdentificeerd door het
     **samengestelde sleutelpaar** `(bridgeName, bridgeVirtualRouter)`, niet
     door `bridgeName` alleen -- de sub-resources moeten dus via
     `.../bridges/{naam},{bridgeVirtualRouter}/...` (met een komma)
     aangesproken worden. Gefixt door dat samengestelde pad te gebruiken.
  5. Met het samengestelde pad gefixt bleven de bridges alle drie zichtbaar
     maar "Down" (bevestigd via screenshots van Broker Manager > Bridges:
     Remote Message VPN/Remote Broker leeg) -- de `POST .../remoteMsgVpns`
     gaf SEMP-fout 11 ("Unknown attribute 'remoteAuthenticationScheme'").
     Oorzaak: de remote-authenticatievelden
     (`remoteAuthenticationScheme`/`remoteAuthenticationBasicClientUsername`/
     `remoteAuthenticationBasicPassword`) horen op het **bridge-object zelf**
     (`.../bridges/{naam},{vr}`, via PATCH), niet op het `remoteMsgVpns`-
     sub-object -- verplaatst.
  6. Met alle 5 bovenstaande fixes toegepast draaide het script volledig
     schoon (0 WARN-regels), en screenshots bevestigden dat de Remote
     Message VPN nu wel werd getoond (`via: <ip>:55443` + de juiste
     remote-VPN-naam per broker) -- toch bleven alle 3 bridges "Down".
     Broker Manager toont zelf geen down-reden, dus is
     `local-broker/semp/diagnose-bridges.sh` toegevoegd (read-only, haalt de
     SEMP v2 **MONITOR**-API op i.p.v. de config-API). Schrijft naar
     `output/diagnose-bridges.txt` (gitignored) i.p.v. stdout, omdat de
     output te lang is om te plakken.
  7. **De output van `diagnose-bridges.sh` gaf de daadwerkelijke oorzaak --
     en die is groter dan een scriptbug.** De onderliggende bridge-
     verbinding was al die tijd al gezond: `remoteMsgVpns[].up: true`,
     `lastConnectionFailureReason: ""`, `rxConnectionFailureCategory:
     "no-failure"`, uptime > 900s, en `remoteRouterName` liet zien dat TLS
     + basic-auth allebei geslaagd waren richting elke cloud-broker. Geen
     verbindingsfout dus, maar het bridge-object had wel
     `"inboundState": "ready-subscribing"` / `"outboundState":
     "not-applicable"`. Een bridge's **`remoteSubscription`** (het enige
     wat een bridge op de LOKALE broker kan configureren) laat de
     **lokale** broker berichten **importeren** vanaf de **remote** VPN --
     niet exporteren.
  8. **Eerste poging tot fix was zelf onjuist, en is teruggedraaid.** Er
     werd verondersteld dat een `localSubscription`-sub-object op de
     bridge het exporteren zou regelen (symmetrisch met
     `remoteSubscriptions`). Dat bleek niet te bestaan: de POST gaf `535
     INVALID_PATH`, en de eerdere CONFIG-GET op het bridge-object had ook
     al nooit een `localSubscriptionsUri` in zijn `links` staan (alleen
     `remoteMsgVpnsUri`/`remoteSubscriptionsUri`/`tlsTrustedCommonNamesUri`/
     `uri`) -- de broker zelf had het antwoord dus al gegeven voordat de
     WARN het bevestigde. Navraag bij Solace's eigen documentatie
     (Message-VPN-Bridges-Overview, Configuring-VPN-Bridges) bevestigt dit:
     er is geen "local subscription"-concept op een bridge. De aanroep is
     verwijderd uit `configure-local-broker.sh`.
  9. **Emils tegenvraag bracht een derde optie naar boven, die nu getest
     wordt.** Een bridge-verbinding is op transport-niveau een gewone,
     bidirectionele TCP/TLS-verbinding -- de vraag was: waarom zou de
     bestaande, al werkende `bridge-to-aws`-verbinding (lokaal dialt uit
     naar AWS) niet hergebruikt kunnen worden voor de exportkant? Solace's
     eigen documentatie bevestigt een relevant mechanisme: een
     "bi-directional bridge" wordt gemaakt door op de ANDERE broker een
     tweede bridge-object toe te voegen dat naar de peer verwijst via zijn
     **virtual router-name** (vorm `v:<naam>`, i.p.v. een IP/FQDN) -- de
     kant die IP/FQDN gebruikt dialt uit, de kant die de router-name
     gebruikt "discovers the existing connection" (letterlijke quote)
     i.p.v. zelf een nieuwe verbinding te openen. Als dat ook voor een
     kale Message-VPN-bridge werkt (niet alleen binnen een DMR-cluster,
     wat niet met zekerheid uit de documentatie blijkt), zou de
     cloud-broker kunnen "meeliften" op de connectie die de lokale
     broker al opende -- zonder dat de lokale broker publiek bereikbaar
     hoeft te zijn.
  10. **Experiment opgezet om dit empirisch te testen (alleen AWS, om
     goedkoop te falen als het niet werkt):** de lokale broker's eigen
     virtual router-name opgevraagd via legacy SEMP
     (`<rpc><show><router-name></router-name></show></rpc>` naar
     `http://localhost:8080/SEMP`) -- dit bleek `3a106d66a729` (herkenbaar
     als de Docker-container-hostname, niet een DNS-naam), nu vastgelegd
     als `LOCAL_ROUTER_NAME` in `local-broker/.env(.example)`. Twee nieuwe
     stukken toegevoegd:
     - `configure-local-broker.sh` sectie 4: maakt een nieuwe, subscribe-
       only client-username `sub-aws` aan op de LOKALE broker (ACL:
       uitsluitend subscriben op `enewable/public/>`, nooit publiceren) --
       symmetrisch aan de bestaande scoped publishers, maar dan in de
       andere richting, voor de reciprocal bridge om mee in te loggen.
     - `cloud-setup/solace-cloud-api/test-reciprocal-bridge-aws.sh`
       (nieuw): maakt, via AWS's eigen SEMP-adminaccount, een bridge
       `bridge-from-enewable` OP de AWS-broker aan, met
       `remoteMsgVpnLocation` = `v:3a106d66a729` (i.p.v. een adres) en
       `remoteSubscriptionTopic` = `enewable/public/>`.
     Uitkomst: **negatief.** Op AWS toont `bridge-from-enewable`
     "Down", Establisher "N/A" -- AWS heeft dus niet eens een poging
     gedaan om `v:3a106d66a729` te resolven, en onze lokale `bridge-to-aws`
     is niet van vorm veranderd (nog steeds gewoon "Down" in de lijst,
     zoals altijd, ondanks de eerder bevestigde gezonde onderliggende
     verbinding). Conclusie: de router-name-discovery uit Solace's
     bi-directional-bridge-documentatie werkt niet voor een kale
     Message-VPN-bridge op zichzelf -- vermoedelijk is hiervoor
     daadwerkelijk DMR-cluster-lidmaatschap tussen de twee brokers nodig
     (waarbinnen router-names pas resolvebaar zijn), wat een veel groter
     traject is dan de resterende tijd tot DADD toelaat. Dit experiment is
     hiermee afgesloten (de testobjecten `bridge-from-enewable` op AWS en
     `sub-aws` lokaal blijven ongebruikt/onschadelijk staan). Terug naar de
     twee eerder genoemde, wél haalbare routes -- aan Emil voorgelegd welke
     kant we op gaan (zie de vraag hieronder in de conversatie, niet
     hierin herhaald):
     - lokale broker publiek bereikbaar maken (tunnel/port-forward/cloud-VM)
       zodat een ECHTE (niet-router-name) reciprocal bridge per cloud-broker
       kan dialen, of
     - bridges loslaten voor de exportkant en een kleine lokale relay-app
       bouwen die, als gewone client, subscribet op de 3 topic-subtrees op
       de lokale broker en elk bericht doorpubliceert naar de bijbehorende
       cloud-broker via een normale uitgaande verbinding (die al bewezen
       werkt) -- geen publieke bereikbaarheid nodig, wel een architecturele
       afwijking van "de broker doet de routering zelf".
  11. **Emil koos een derde, betere optie: native REST Delivery Points
     (RDP) i.p.v. bridges of een relay-app.** Emils voorstel: "app (stm,
     sdkperf etc) keep publishing to topic. Create queues on localhost
     that attract messages from relevant topic categories ... Then use
     these queues as source for RDPs to cloud brokers." Dit combineert het
     beste van beide eerder afgewogen routes -- geen publieke
     bereikbaarheid nodig (de RDP dialt zelf uit, net als een bridge doet),
     én geen relay-app nodig (de broker doet de routering zelf, via een
     100% SEMP-geconfigureerde, native feature). Twee zaken zijn hierbij
     uitgezocht en bevestigd vóór implementatie, om niet een derde keer een
     verkeerd schema te raden (zie punten 7-8 hierboven):
     - **Werkt dit met DIRECT-berichten, of moeten de demo-apps naar
       guaranteed/persistent messaging omgezet worden?** Bevestigd via
       Solace's eigen documentatie
       (Messaging/Guaranteed-Msg/Topic-Matching-and-Delivery-Modes.htm,
       "message promotion"): een DIRECT-bericht dat een topic-match heeft
       met een queue's subscription wordt automatisch door die queue
       opgevangen -- "No special configuration is required". **Geen
       appwijziging nodig** -- stm/python/sdkperf blijven ongewijzigd
       DIRECT publiceren.
     - **Exacte SEMP v2-attribuutnamen voor `restDeliveryPoints`,
       `queueBindings`, `restConsumers`, `queues` en
       `queues/{q}/subscriptions`.** Solace's eigen CLI-documentatie
       (Services/Managing-RDPs.htm) geeft alleen CLI-syntax, geen
       REST-attribuutnamen. Gecrosscheckt tegen een werkende Go SEMP-client
       (`github.com/koverton/semp_client`, struct/JSON-tags) i.p.v. verder
       te raden: `restDeliveryPointName`/`clientProfileName`/`enabled`
       (RDP); `queueBindingName`/`postRequestTarget` (queue-binding);
       `restConsumerName`/`remoteHost`/`remotePort`/`tlsEnabled`/
       `authenticationScheme`/`authenticationHttpBasicUsername`/
       `authenticationHttpBasicPassword`/`enabled` (rest-consumer);
       `queueName`/`accessType`/`permission`/`ingressEnabled`/
       `egressEnabled` (queue); `subscriptionTopic` (queue-subscription).
     - **Topic-behoud end-to-end**: Solace's REST-publish-service leest de
       topic uit het URL-pad van de POST (bevestigd via
       tutorials.solace.dev/rest-messaging/publish-subscribe: `POST
       .../solace/samples/rest` publiceert op topic
       `solace/samples/rest`). De queue-binding gebruikt daarom
       `"postRequestTarget": "/${topic()}"` -- Solace's
       substitution-expression-syntax voor "de volledige originele topic"
       (Messaging/Substitution-Expressions-Overview.htm) -- zodat een
       bericht op `enewable/public/plant-1/telemetry` lokaal ook op
       precies die topic op de cloud-broker verschijnt, in plaats van op
       een vast pad.
     Geïmplementeerd in het nieuwe `local-broker/semp/configure-rdp-export.sh`:
     3 queues (`q-export-public`/`q-export-eu-ops`/`q-export-eu-pii`) met
     topic-subscription, 3 RDP's (`rdp-aws`/`rdp-azure`/`rdp-stackit`) elk
     met 1 queue-binding en 1 rest-consumer. De rest-consumer hergebruikt de
     bestaande `enewable-local-bridge`-credentials (al publish-only
     ACL-gescoped per cloud-broker) -- geen nieuwe secrets nodig.
     **Nog open, moet Emil zelf checken/invullen** (geen toegang tot Solace
     Cloud console vanuit deze sessie): `*_REMOTE_REST_HOST`/
     `*_REMOTE_REST_PORT` in `local-broker/.env(.example)` zijn ingevuld
     met de aanname "zelfde hostname als SMF, poort 9443" (Solace Cloud's
     standaard secure-REST-poort) -- controleer dit op de Connect-tab van
     elke service (REST-sectie) en **zet het REST-messaging-protocol aan**
     voor die service als dat nog niet zo is (in tegenstelling tot
     SMF/Web-messaging staat REST niet altijd standaard aan).
  12. **Opgeruimd: de nu-obsolete bridge-configuratie en -experimenten,
     zoals Emil vroeg.** Nu de RDP-route werkt volgens plan, dienden de
     bridge-gerelateerde bestanden en configuratie geen doel meer en zijn
     verwijderd/aangepast:
     - Sectie 3 (3 bridges) en sectie 4 (`sub-aws`-testgebruiker) zijn uit
       `local-broker/semp/configure-local-broker.sh` verwijderd; het script
       richt nu alleen nog de Message VPN en de 3 scoped publishers in.
     - `local-broker/semp/diagnose-bridges.sh` en
       `cloud-setup/solace-cloud-api/test-reciprocal-bridge-aws.sh` zijn
       verwijderd (`git rm`) -- beide bestonden alleen om de
       bridge-aanpak te diagnosticeren/testen.
     - `LOCAL_ROUTER_NAME` en `SUB_AWS_USER`/`SUB_AWS_PASSWORD` zijn uit
       `local-broker/.env(.example)` verwijderd (waren alleen relevant voor
       het afgesloten router-name-experiment).
     - `AWS_BRIDGE_USER`/`AWS_BRIDGE_PASSWORD` (en de Azure/STACKIT-
       equivalenten) blijven bestaan -- deze credentials zijn nu de RDP's
       REST-consumer-auth, niet meer een bridge's remote-auth. De naam is
       met opzet niet veranderd (voorkomt een overbodige her-provisioning
       op elke cloud-broker); dit staat nu overal expliciet in de
       commentaren in `.env(.example)` en in `docs/cloud-brokers.md`.
     - Alle documentatie (`docs/lokale-broker.md`, `docs/topologie.md`,
       `docs/cloud-brokers.md`, `docs/demo-apps.md`,
       `demo-apps/README.md`, `local-broker/README.md`,
       `cloud-setup/README.md` en de 4 provider-`README.md`'s, dit bestand)
       is bijgewerkt om consistent over queues + REST Delivery Points te
       spreken in plaats van bridges als het huidige exportmechanisme --
       de bridge-episode (waarom het niet werkte, wat er geprobeerd is)
       blijft staan als historie, niet als instructie voor wat nu te
       draaien.
     - `cloud-setup/solace-cloud-api/configure-remote-bridge-users.sh`
       blijft bestaan (het maakt de credentials die de RDP nu gebruikt) --
       alleen het scriptnaam is historisch, de header-comment legt dit nu
       uit.
     Niet verwijderd, met opzet: de historische beschrijving hierboven
     (punten 6-11) van *waarom* bridges niet werkten en *wat* er geprobeerd
     is -- dat is waardevolle context voor de presentatie/nagesprek, geen
     instructie om opnieuw te draaien.
  13. **Eerste echte testrun van `configure-rdp-export.sh` (Emil, 28/09/2026)
     vond meteen 1 scriptbug, nu gefixt.** De queues, RDP's en
     queue-bindings werden alle 9 correct aangemaakt (0 WARN), maar de
     `restConsumers`-POST gaf voor alle 3 RDP's SEMP-fout 11: `"Problem
     with authenticationScheme: Invalid value. basic is not one of the
     available options (['none', 'http-basic', 'client-certificate',
     'http-header', 'oauth-client', 'oauth-jwt', 'transparent', 'aws'])"`.
     Oorzaak: `"basic"` is de waarde die bridges gebruiken
     (`remoteAuthenticationScheme`), maar een rest-consumer's
     `authenticationScheme` gebruikt een ander enum, met koppeltekens:
     `"http-basic"`. De Go-client die de VELDNAMEN bevestigde (zie punt 11)
     bevestigde dus niet ook de geldige WAARDEN -- die kwamen deze keer pas
     naar boven via de broker's eigen foutmelding, net als bij de eerdere
     bridge-bugs. Gefixt in `configure-rdp-export.sh` (en met dit
     bugverslag zelf gedocumenteerd, ook inline in het script). Script is
     idempotent: de 9 al aangemaakte objecten worden overgeslagen
     ("already exists"), alleen de 3 rest-consumers worden nu alsnog
     aangemaakt bij een herhaalde run. **Herhaalde run (Emil, 28/09/2026):
     0 WARN** -- de 9 bestaande objecten correct overgeslagen, de 3
     rest-consumers nu zonder fout aangemaakt.
  14. **Broker Manager-check: alle 3 RDP's tonen "Operational State: Down"**
     (screenshot, Clients > REST > RDPs). Eén mogelijke oorzaak alvast
     **uitgesloten**: de aanname "zelfde hostname als SMF, poort 9443" is
     bevestigd correct via de Connect-tab van de AWS-service zelf
     (screenshot toont exact `https://mr-connection-07w9t1ah76x.messaging.
     solace.cloud:9443` onder "Solace REST Messaging API") -- dit is dus
     geen host/poort-probleem. Broker Manager geeft, net als eerder bij de
     bridges (zie punt 6/7 hierboven), geen down-reden. Nieuw, analoog
     diagnostisch script toegevoegd:
     `local-broker/semp/diagnose-rdp.sh` (read-only, GET's zowel de CONFIG-
     als de MONITOR-SEMP-v2-view van elke RDP, zijn rest-consumer en zijn
     gebonden queue, schrijft naar `output/diagnose-rdp.txt`, gitignored) --
     wacht op Emils run en de output om de echte oorzaak te vinden in
     plaats van te gokken (verkeerde credentials, TLS-vertrouwen,
     REST-messaging niet aangezet op de cloud-VPN, of iets anders).
  15. **`diagnose-rdp.txt` (Emil, 28/09/2026) laat zien: de REST-consumer
     zelf is gezond, het probleem zit bij de queue-binding.** Per RDP:
     `restConsumers/consumer-*` toont `"up": true`,
     `"remoteOutgoingConnectionUpCount": 3` (== `outgoingConnectionCount`)
     -- de TLS+http-basic-verbinding naar elke cloud-broker werkt dus
     daadwerkelijk. De wél aanwezige `"lastConnectionFailureReason": "Peer
     TCP Closed"` en `"lastFailureReason": "No Consumer Connections Up"`
     zijn **historisch** (tijdstip identiek aan de EERSTE, mislukte run
     vóór de authenticationScheme-fix) -- geen actueel probleem. Het echte
     signaal staat op de RDP zelf, niet de consumer:
     `"up": false`, `"lastFailureReason": "No REST Queue Bindings Up"`
     (zelfde tijdstip voor alle 3 RDP's -- vermoedelijk een
     reconciliatie-moment vlak na de fix-run). `diagnose-rdp.sh` had de
     queue-binding zelf nooit opgevraagd (alleen de queue en de RDP/
     consumer) -- toegevoegd: GET op
     `restDeliveryPoints/{rdp}/queueBindings/{queue}` (CONFIG + MONITOR)
     en op `queues/{queue}/subscriptions` (om de topic-subscriptie zelf te
     bevestigen, in plaats van te concluderen uit de lege
     `"collections": {"subscriptions": {}}`-placeholder in de queue's
     eigen GET -- die is normaal leeg totdat je de sub-collectie zelf
     opvraagt, dus geen signaal op zich). Emil moet `diagnose-rdp.sh`
     nogmaals draaien met deze uitgebreide versie.
  16. **`diagnose-rdp.txt` (ronde 2, Emil, 28/09/2026) wijst de oorzaak aan:
     de queue-binding faalt met HTTP 503 "Service Unavailable".** Elke
     queue-binding toont nu `"up": false"`, `"uptime": 0` en
     **`"lastFailureReason": "Service Unavailable"`** -- de onderliggende
     TLS+http-basic-verbinding van de RDP's rest-consumer naar elke
     cloud-broker is bevestigd gezond (`"up": true`,
     `remoteOutgoingConnectionUpCount` == `outgoingConnectionCount` voor
     alle 3), en de topic-subscriptie op de queue is onafhankelijk
     bevestigd aanwezig en correct (`GET .../queues/{queue}/subscriptions`
     toont bv. `"subscriptionTopic": "enewable/public/>"`). Dus: de
     verbinding komt tot stand, maar de daadwerkelijke POST wordt door de
     doelbroker afgewezen. Vermoedelijke (nog niet bevestigde) oorzaak,
     conform de al langer bestaande waarschuwing in
     `local-broker/.env.example` dat REST "niet altijd standaard aan staat
     zoals SMF/Web-messaging": de REST-incoming service staat niet aan op
     de doel-Message-VPN. Nieuw script toegevoegd:
     `cloud-setup/solace-cloud-api/enable-rest-on-cloud-vpns.sh` (leest
     `local-broker/.env`, checkt en zet zo nodig
     `serviceRestIncomingTlsEnabled` aan op elk van de 3 cloud-VPN's, via
     elke broker's eigen SEMP v2 Config API met de bestaande
     `*_SEMP_ADMIN_USER`/`PASSWORD`-credentials). Dit script moet Emil
     zelf draaien (deze sessie kan `*_SEMP_HOST` niet bereiken, zie sectie
     13 hierboven) en daarna `diagnose-rdp.sh` nogmaals draaien om te
     checken of de queue-binding se `lastFailureReason` verandert en de
     RDP zelf op `"up": true"` komt. **Niet gegarandeerd de fix** -- als
     dit het niet oplost, moet gekeken worden naar andere 503-oorzaken
     (client-profile REST-rechten op de cloud-VPN, VPN-spool/
     shutdown-status).
  17. **Derde `diagnose-rdp.sh`-run (Emil, 28/09/2026, 09:37Z) bevestigt: de
     503 op de queue-binding blijft bestaan.** Alle 3 queue-bindings tonen
     opnieuw `"up": false"`, `"uptime": 0"`,
     `"lastFailureReason": "Service Unavailable"` -- de `lastFailureTime`
     valt vrijwel exact samen met het moment van deze diagnose-run, wat
     past bij de RDP's automatische `retryDelay: 3s` reconnect-lus (dus dit
     is een actuele, herhaalde mislukking, geen oude/stale waarde). Nog
     onduidelijk of dit gemeten is vóór of na een run van
     `enable-rest-on-cloud-vpns.sh` -- als het probleem blijft bestaan
     terwijl REST-incoming al aan bleek te staan (of aangezet is), is de
     "REST-incoming staat uit"-theorie (punt 16) ontkracht en moet er
     dieper gekeken worden dan de RDP's eigen state. Nieuw script
     toegevoegd om dat te doen: `cloud-setup/solace-cloud-api/
     test-rest-direct.sh` -- bypasst de RDP volledig en POST't
     rechtstreeks (curl, met dezelfde http-basic credentials) naar elke
     cloud-broker se REST-endpoint, zodat de échte HTTP-statusregel en
     responsebody zichtbaar worden in plaats van de RDP's samengevatte
     "Service Unavailable". Emil moet dit draaien (en zeggen of
     `enable-rest-on-cloud-vpns.sh` al gedraaid is, en wat die liet zien
     voor `serviceRestIncomingTlsEnabled` vóór de PATCH).
  18. **`test-rest-direct.sh` (Emil, 28/09/2026) doorbreekt de aanname: alle
     3 cloud-brokers accepteren een rechtstreekse curl-POST met `HTTP/1.1
     200 OK`.** Zelfde host, poort, http-basic credentials en topic-uit-
     pad-constructie als de RDP gebruikt -- en het werkt gewoon. Dit sluit
     REST-incoming-uitgeschakeld, verkeerde auth, host/poort en topic-
     mapping definitief uit als oorzaak van de 503. Bevestigd via
     `enable-rest-on-cloud-vpns.sh`: op Azure stond
     `serviceRestIncomingTlsEnabled` al op `true` **vóórdat** de PATCH
     liep -- dus die theorie (punt 16) was voor Azure al onwaar, en
     vermoedelijk ook voor AWS/STACKIT (zelfde manier geprovisioned).
     Cruciale aanvullende aanwijzing, al aanwezig in de ronde-2
     `diagnose-rdp.txt` maar tot nu niet expliciet benoemd: de
     REST-consumer se eigen HTTP-tellers
     (`httpRequestTxMsgCount`, `httpResponseSuccessRxMsgCount`,
     `httpResponseErrorRxMsgCount`, etc.) staan voor alle 3 op **0** -- de
     consumer heeft dus nog **nooit** daadwerkelijk een POST voor een
     echt bericht verstuurd. De "Service Unavailable" op de queue-binding
     kan dus geen mislukte *bericht*-aflevering zijn (die heeft nog niet
     plaatsgevonden); het is vermoedelijk een RDP-interne
     gereedheids-/probe-stap die los staat van échte berichtaflevering.
     **Vervolgstap, nog niet uitgevoerd:** een echte end-to-end publish-
     test (bijv. `demo-apps/stm-public/publish-public.sh`) om te zien of
     een bericht daadwerkelijk in de queue landt (`spooledMsgCount`) en of
     de REST-consumer se tellers dan van 0 af bewegen -- dat zegt meer dan
     de RDP se eigen Up/Down-status alleen. `enable-rest-on-cloud-vpns.sh`
     en `test-rest-direct.sh` zijn beide aangepast om ook naar
     `output/*.txt` te schrijven (zelfde conventie als `diagnose-rdp.sh`),
     zodat toekomstige runs makkelijker te delen zijn.
  19. **Eerste poging tot de echte end-to-end publish-test (Emil,
     28/09/2026) liep meteen vast op de demo-app zelf, niet op de
     RDP-keten:** `demo-apps/stm-public/publish-public.sh` faalde met
     `error: unknown option '--url'` op de regel `stm publish \`. Oorzaak:
     de geïnstalleerde Solace Try-Me CLI (stm v1.0.0) heeft helemaal geen
     `publish`-subcommando -- de echte command-tree is
     `send`/`receive`/`request`/`reply`/`config`/`manage`/`feed` (bevestigd
     via de officiële `SolaceLabs/solace-tryme-cli`-documentatie op
     GitHub: `MESSAGING_PARAMETERS.md` en het README). Alle gebruikte
     vlaggen (`--url`, `--vpn`, `--username`, `--password`, `--topic`,
     `--file`, `--count`, `--interval`) bestaan wél, alleen onder
     `stm send` in plaats van `stm publish`. Gefixt in
     `demo-apps/stm-public/publish-public.sh` en
     `demo-apps/stm-public/README.md` (2 vindplaatsen). De echte
     end-to-end test (landt het bericht in de queue, bewegen de
     REST-consumer se tellers van 0 af, komt het aan op AWS) moet Emil nu
     opnieuw draaien.
  20. **Na de stm-fix loopt de publish-test meteen vast op een NIEUW,
     apart probleem: de LOKALE broker wijst `pub-public` af** met
     `error: connection failed to the message router / The RADIUS profile
     is shutdown - - check the connection parameters!` (Emil,
     28/09/2026). Dit staat los van het RDP/503-onderzoek (punten 14-19)
     -- het gaat mis op de allereerste hop, stm -> lokale broker over
     Web Messaging (`ws://localhost:8008`), vóórdat er ook maar íets bij
     een cloud-broker aankomt. Verdacht: Solace's eigen error-subcode-
     documentatie (de JS-clientlibrary waar stm op gebouwd is) kent
     losse "administratief shutdown"-redenen (`CLIENT_USERNAME_IS_
     SHUTDOWN`, `BASIC_AUTHENTICATION_IS_SHUTDOWN`), maar "The RADIUS
     profile is shutdown" hoort specifiek bij een VPN waarvan het
     basic-auth-type op "radius" staat terwijl er geen werkend RADIUS-
     profiel is -- een vers aangemaakte Message VPN staat normaal op
     "internal" auth, dus als dit klopt heeft iets `authenticationBasic
     Type` op de `enewable`-VPN op "radius" gezet (of eerdere
     experimenten hebben dat achtergelaten); `configure-local-broker.sh`
     zet dit veld nergens expliciet, dus het verklaart het probleem ook
     niet weg. Nieuw diagnostisch script:
     `local-broker/semp/diagnose-local-auth.sh` (read-only, checkt VPN
     enabled/basic-auth-type/radius-profiles, client-profile "default",
     en alle 4 client-usernames se enabled-status) -- moet Emil draaien
     vanuit zijn eigen terminal (de sandbox van de assistent kan
     `localhost:8080` niet bereiken, andere VM dan waar Docker draait).
  21. **`diagnose-local-auth.txt` (Emil, 28/09/2026) bevestigt de
     RADIUS-theorie exact:** `authenticationBasicType` op de
     `enewable`-VPN staat op `"radius"` (met een lege
     `authenticationBasicRadiusDomain`, en er is helemaal geen RADIUS-
     profiel geconfigureerd -- `GET .../authenticationRadiusProfiles`
     geeft zelfs een `INVALID_PATH`-fout, wat past bij "geen radius-setup
     aanwezig, maar de VPN denkt toch dat ze radius moet gebruiken"). Alle
     4 client-usernames (`pub-public`, `pub-eu-ops`, `pub-eu-pii`) staan
     gewoon op `enabled: true` met de juiste ACL/profile -- dit was dus
     nooit een probleem met een individuele username. (`enewable-local-
     bridge` bestaat terecht niet op de lokale broker -- die credential
     hoort alleen bij de 3 cloud-brokers, als REST-consumer-auth voor de
     RDP's; een 404 daarop is verwacht, geen fout.) **Gefixt:**
     `configure-local-broker.sh` PATCHt de VPN nu expliciet naar
     `authenticationBasicType: "internal"` (was nergens eerder expliciet
     gezet) -- idempotent, dus voortaan zelfherstellend als dit ooit
     opnieuw gebeurt. **Nog los te bevestigen, geen actie ondernomen:**
     het `default` client-profile heeft
     `allowGuaranteedMsgSendEnabled: false` -- dit zou normaliter geen rol
     mogen spelen bij message-promotion van een DIRECT-publicatie naar een
     queue (de publisher blijft op DIRECT QoS; de broker dupliceert
     intern), maar als na de RADIUS-fix berichten nog steeds niet in de
     queue belanden, is dit de volgende kandidaat om te checken.
  22. **Publish-test na de RADIUS-fix: verbinding lukt nu, maar elk
     bericht wordt geweigerd met "Sending guaranteed message is not
     allowed by router for this client" (Emil, 28/09/2026).** Precies
     het net genoemde watch-item, maar dan bevestigd: `stm send`
     publiceert **standaard PERSISTENT** (guaranteed), niet DIRECT --
     zichtbaar in de output ("1 publishing PERSISTENT message"). Het
     `default` client-profile heeft bewust
     `allowGuaranteedMsgSendEnabled: false`, want deze hele demo is
     gebouwd op DIRECT-publiceren + automatische queue-promotion (zie
     "Definitieve keuze" in `docs/lokale-broker.md`) -- dus dit is geen
     broker-misconfiguratie maar de publish-test die de verkeerde
     delivery-mode gebruikte. Gefixt: `--delivery-mode DIRECT`
     toegevoegd aan `demo-apps/stm-public/publish-public.sh` (en het
     handmatige voorbeeld in `stm-public/README.md`). De andere 2
     demo-apps hadden dit probleem niet: `sdkperf-pii` gebruikte al
     `-mt=direct`, en `python-eu-nonpersonal` gebruikte al
     `create_direct_message_publisher_builder()`.
  23. **Publish-test na de delivery-mode-fix: bericht landt eindelijk in
     de lokale queue, maar komt niet aan op AWS (Emil, 28/09/2026).**
     `diagnose-rdp.sh` (ronde 4) bevestigt: `q-export-public` heeft nu
     `spooledMsgCount: 10`, `msgSpoolUsage: 1920`,
     `highestMsgId: 10` -- de 10 gepubliceerde berichten zijn dus
     daadwerkelijk in de queue beland via message-promotion (dit
     mechanisme werkt dus gegarandeerd correct). Maar: de REST-consumer
     se HTTP-tellers (`httpRequestTxMsgCount` etc.) staan nog steeds op
     **0** voor alle 3, en de queue-binding blijft `"lastFailureReason":
     "Service Unavailable"` tonen, met een `lastFailureTime` die exact
     samenvalt met het moment van de diagnose-run (net als ronde 2/3) --
     dus de queue-binding heeft nooit ook maar één poging gedaan om de
     10 wachtende berichten daadwerkelijk te posten. Bevestigd met een
     screenshot van de AWS "Try Me!"-tab: subscriber op `enewable/public/>`
     toont 0 berichten. **Root cause gevonden** (via de
     `solacebroker`-Terraform-provider se resource-documentatie, die dit
     veld wél beschrijft waar Solace's CLI-only RDP-doc het niet doet):
     `requestTargetEvaluation` op de queue-binding staat standaard op
     `"none"` -- substitutie-expressies zoals `${topic()}` worden dan
     **niet geëvalueerd**. `configure-rdp-export.sh` zette dit veld nooit,
     dus elke queue-binding postte al die tijd naar het LETTERLIJKE,
     niet-geëvalueerde pad `/${topic()}` -- nooit naar de echte topic.
     Dit verklaart vermoedelijk ook de 503 zelf: een letterlijke
     `${...}`-sequentie in een URL-pad is precies het patroon dat
     Log4Shell-tijdperk WAF/CDN-regels blokkeren, en zou verklaren waarom
     de REST-consumer se tellers nooit bewogen (wat er ook onderschepte,
     liet het nooit als een normaal verzonden bericht registreren).
     **Gefixt:** `configure-rdp-export.sh` zet nu
     `requestTargetEvaluation: "substitution-expressions"` bij het
     aanmaken van elke queue-binding, plus een aparte, onvoorwaardelijke
     PATCH zodat ook de 3 al bestaande (foutieve) queue-bindings
     gecorrigeerd worden.
  24. **`requestTargetEvaluation`-fix bevestigd LIVE op de broker (ronde 5,
     `diagnose-rdp.txt` 10:50:47Z), maar de 503 verandert geen millimeter
     (Emil, 28/09/2026).** De CONFIG-view van alle 3 queue-bindings toont nu
     terecht `"requestTargetEvaluation": "substitution-expressions"` -- de
     fix uit punt 23 staat dus daadwerkelijk op de broker. Maar de
     MONITOR-view is byte-voor-byte identiek aan vóór de fix:
     `"lastFailureReason": "Service Unavailable"`, `"up": false`,
     `"uptime": 0` op de queue-binding, en de REST-consumer se
     HTTP-tellers (`httpRequestTxMsgCount` e.a.) staan nog steeds op **0**
     -- ook al is `spooledMsgCount` inmiddels doorgegroeid naar 20 (twee
     publish-testruns). **Conclusie: punt 23's theorie was een reële bug
     en terecht gefixt, maar niet de (enige) oorzaak van de 503** -- de
     werkelijke oorzaak is nog niet gevonden.
     **Nieuw spoor, tot nu toe niet opgemerkt:** de REST-consumer se eigen
     monitor-data bevat een veld dat niemand eerder goed had gelezen:
     `"lastConnectionFailureReason": "Peer TCP Closed"`, met een
     `lastConnectionFailureTime` die typisch een paar seconden vóór de
     queue-binding se eigen `lastFailureTime` ligt. Dit beschrijft iets
     anders dan `"up": true` / `remoteOutgoingConnectionUpCount: 3` (dat
     is de staat op het moment van de SEMP-meting) -- het zegt dat de
     CLOUD-broker zelf de persistente/keep-alive verbindingen van de
     REST-consumer-pool (`outgoingConnectionCount: 3`) actief dichtgooit.
     Als de queue-binding een bericht wil posten via een verbinding die
     net dichtgegooid is of aan het dichtgaan is, kan dat mislukken
     vóórdat er ook maar iets als "verzonden bericht" geteld wordt --
     wat zou verklaren waarom `httpRequestTxMsgCount` op 0 blijft staan
     én waarom een losse curl-POST (die altijd een NIEUWE verbinding
     opent en die na 1 request weer sluit, dus nooit een pool hergebruikt)
     wél altijd slaagt terwijl de RDP se persistente pool nooit aflevert.
     **Nog niet bewezen, wel getest kan worden:** nieuw diagnosescript
     `local-broker/semp/watch-rdp-live.sh` toegevoegd -- pollt (read-only)
     alle 3 REST-consumers en queue-bindings elke 2 seconden gedurende
     ~30 seconden, direct ná een publish-test, om te zien of
     `httpRequestTxMsgCount` ooit al is het maar heel even van 0 afgaat,
     en of `lastConnectionFailureTime` steeds opnieuw net vóór het
     meetmoment ligt (= continue connect/drop-lus, niet een oude,
     eenmalige waarde). Emil moet dit draaien: eerst een publish-test,
     dan meteen `./watch-rdp-live.sh`.
  25. **Eerste run van `watch-rdp-live.sh` leverde alleen `null`-waarden op
     voor alle consumer/binding-velden (Emil, 28/09/2026) -- een bug in
     het script zelf, geen nieuwe broker-info.** Oorzaak: de `jq`-filter
     las de velden van het top-level JSON-object i.p.v. van `.data`
     (SEMP v2 wrapt alle content onder een `"data"`-key), dus elk veld
     was per definitie afwezig. De queue-regel (`spooledMsgCount`) werkte
     wél correct (die filterde al op `.data`) en toont `q-export-public`
     inmiddels op 30 wachtende berichten -- consistent met het screenshot
     van Broker Manager. **Gefixt:** filter aangepast naar
     `.data | {up, uptime, ...}`. Omdat er al 30 berichten in de
     AWS-queue liggen (over meerdere retry-cycli heen, gezien
     `retryDelay: 3`), hoeft Emil niet opnieuw te publiceren -- gewoon
     `./watch-rdp-live.sh` nogmaals draaien is genoeg om punt 24's
     hypothese (`"Peer TCP Closed"` op de persistente verbindingspool)
     te toetsen.
  26. **`watch-rdp-live.txt` (herhaalde run, correcte tellers) toont de
     echte root cause: de queue-binding bindt zich helemaal nooit aan zijn
     eigen lokale queue (Emil, 28/09/2026).** Over 15 metingen (~35
     seconden) blijven `httpRequestTxMsgCount`, `httpResponseSuccessRxMsgCount`
     en `httpResponseErrorRxMsgCount` op alle 3 consumers permanent op 0 --
     zelfs terwijl de queue 30 berichten bevat en de REST-consumer se
     verbindingen het grootste deel van die tijd gewoon gezond zijn
     (`"up": true`, `remoteOutgoingConnectionUpCount: 3`). Bovendien:
     `bindRequestCount: 0` / `bindSuccessCount: 0` op de queue, exact
     consistent met "Consumers: 0" in de Broker Manager-schermafbeelding
     (had 1 moeten zijn -- de RDP zelf). Punt 24's `"Peer TCP Closed"`-spoor
     is hiermee een **rode haring**: de queue-binding faalt met
     `"Service Unavailable"` op bijna elke ~2s-poging **onafhankelijk** van
     of de REST-consumer op dat moment gezond is of niet (1 keer, sample 9,
     zagen we de consumer daadwerkelijk kortstondig naar 0/3 verbindingen
     gaan en toen meldde de binding wél terecht `"No REST Consumers Up"` --
     in alle ANDERE samples, met een gezonde consumer, bleef het toch
     `"Service Unavailable"`). Conclusie: de binding komt nooit verder dan
     een poging tot binden aan de LOKALE queue -- de REST-aflevering wordt
     nooit eens bereikt.
     **Root cause gevonden:** zowel het RDP-object als alle demo-app
     client-usernames gebruiken `clientProfileName: "default"`
     (`configure-local-broker.sh` / `configure-rdp-export.sh`), en
     `diagnose-local-auth.txt` had al laten zien (28/09/2026, tot nu toe
     niet aan dit onderzoek verbonden) dat dit profiel
     `allowGuaranteedMsgReceiveEnabled: false` heeft. Het binden van een
     RDP aan zijn eigen durable queue om berichten te dequeuen is precies
     een guaranteed-message-RECEIVE-operatie -- als het clientprofiel dat
     verbiedt, kan de binding nooit tot stand komen. Dit verklaart elk
     symptoom: de bind registreert nooit (`bindRequestCount` blijft 0),
     er wordt nooit een bericht gedequeued om te posten
     (`httpRequestTxMsgCount` blijft 0), en de generieke
     `"Service Unavailable"` is wat de broker meldt als hij de operator
     niets specifieker kan vertellen over waarom de binding niet omhoog
     komt.
     **Gefixt:** `configure-rdp-export.sh` maakt nu een los
     client-profile `rdp-deliver` aan met
     `allowGuaranteedMsgReceiveEnabled: true` (en voor de zekerheid ook
     `allowGuaranteedMsgSendEnabled: true`), en elke RDP wordt
     aangemaakt/gepatcht om dit profiel te gebruiken in plaats van
     `"default"` -- de demo-app publishers blijven ongewijzigd op
     `"default"` staan, dus dit raakt niets anders.
  27. **Sanity-check vóór de profiel-fix: handmatige curl-POST rechtstreeks
     naar AWS bevestigt dat AWS-kant, credentials en topic-mapping
     volledig los van het lokale-broker-probleem staan (Emil,
     28/09/2026).** Zelfde aanpak als `test-rest-direct.sh`, maar
     handmatig uitgevoerd om ook de visuele aankomst in Try Me! te
     bevestigen (dat had de eerdere `test-rest-direct.sh`-run nooit
     expliciet laten zien): `curl -u ${AWS_BRIDGE_USER}:${AWS_BRIDGE_PASSWORD}
     -X POST https://${AWS_REMOTE_REST_HOST}:${AWS_REMOTE_REST_PORT}/enewable/public/curl-sanity-check`
     geeft `HTTP/1.1 200 OK`, en het bericht verschijnt meteen in de AWS
     "Try Me!"-subscriber op `enewable/public/>`
     (`2026-09-28 13:28:59:336 [Topic enewable/public/curl-sanity-check]`,
     Direct, inhoud "manual curl sanity check, ..."). Dit bevestigt
     definitief: AWS-credentials, REST-incoming, TLS/poort en
     topic-naar-URL-mapping zijn 100% in orde -- het probleem zit
     uitsluitend op de lokale broker (punt 26's `rdp-deliver`-profiel-fix),
     niet aan de AWS-kant.
  28. **✅ BEVESTIGD OPGELOST: `configure-rdp-export.sh` herdraaien +
     `diagnose-rdp.sh` + AWS "Try Me!" tonen de volledige RDP-keten
     werkend, end-to-end (Emil, 28/09/2026).** Na de `rdp-deliver`-fix
     (punt 26):
     - Alle 3 queue-bindings staan nu op `"up": true` met `bindRequestCount: 1`
       / `bindSuccessCount: 1` op hun queue -- de RDP is dus voor het eerst
       daadwerkelijk gebonden aan zijn eigen lokale queue (was 0/0 in elke
       eerdere meting).
     - Voor `rdp-aws` (die al 30 wachtende berichten had):
       `httpRequestTxMsgCount: 24`, `httpResponseSuccessRxMsgCount: 21`,
       `httpResponseErrorRxMsgCount: 0`, `httpRequestOutstandingTxMsgCount: 3`
       -- de REST-consumer post nu daadwerkelijk berichten en krijgt
       succesvolle responses terug (was overal exact 0). De queue drainde
       van 30 naar 9 resterende berichten binnen enkele seconden.
     - AWS "Try Me!" toont het bewijs zelf: Messages ging van 1 (de eerdere
       handmatige curl-sanity-check) naar **31 Direct** -- het nieuwste
       bericht, `2026-09-28 13:37:41 [Topic enewable/public/market/price]`
       met inhoud `{"source": "enewable-market-feed", "type":
       "day-ahead-price", ...}`, is een ECHT demo-berichten, aangekomen via
       de volledige keten (publish -> lokale queue -> RDP -> AWS) op
       precies dezelfde topic-structuur.
     - `rdp-azure` en `rdp-stackit` tonen dezelfde `up: true` /
       `bindSuccessCount: 1` -- klaar en wachtend, alleen nog geen verkeer
       omdat er nog niet op `enewable/eu/ops/>` of `enewable/eu/pii/>` is
       gepubliceerd in deze testronde.
     De `"RDP (Is) Shutdown"`/`"No REST Consumers Up"`-meldingen die nog in
     de output staan zijn eenmalige, verwachte blips van het moment
     waarop het script het RDP-object herconfigureerde (het object gaat
     kort omlaag en weer omhoog bij een PATCH) -- geen actief probleem,
     aangezien `"up": true` op alle niveaus blijft staan.
     **Conclusie: de volledige RDP-exportketen werkt nu end-to-end voor
     AWS, en staat klaar voor Azure/STACKIT.** Sectie 14, stap 5 (de
     eerste volledige testronde met alle 3 demo-apps) is de logische
     vervolgstap.
  29. **Volledige testronde (sectie 12, punten 2-4) in uitvoering (Emil,
     28/09/2026):**
     - ~~`stm-public/publish-public.sh` -> alleen AWS.~~ ✅ Geslaagd.
     - `python-eu-nonpersonal/publisher.py` -> alleen Azure: eerste poging
       faalde met `ERROR: Invalid requirement: '#'` gevolgd door
       `ModuleNotFoundError: No module named 'dotenv'` -- geen bug in de
       repo, maar een instructiefout van de assistent: de meegegeven
       commando's hadden een `# first time only`-toelichting achter
       `pip install -r requirements.txt` op dezelfde regel. bash negeert
       zo'n inline `#`-commentaar in interactieve shells, maar Emil se
       shell is **zsh** (macOS-default), die dat standaard NIET doet
       (`interactivecomments`-optie staat standaard uit) -- dus `#`,
       `first` en `only` werden als drie extra, letterlijke argumenten aan
       `pip` doorgegeven, en pip weigerde `#` als ongeldige package-naam
       nog vóórdat er iets geïnstalleerd was (dus ook `python-dotenv`
       niet, vandaar de `ModuleNotFoundError` erna). Geen opschoning
       nodig: de venv-regel had toevallig geen kwaadaardige neveneffecten
       (bevestigd, geen rondslingerende map's `#`/`first`/`only`
       aangemaakt). **Fix:** dezelfde commando's zonder inline
       `#`-commentaar opnieuw laten draaien. ~~Opnieuw draaien.~~ ✅
       Geslaagd: 20 Direct-berichten op Azure "Try Me!"
       (`enewable/eu/ops/grid/load`), niets op AWS.
     - `sdkperf-pii/publish-pii.sh` -> alleen STACKIT: eerste poging liep vast
       op `line 20: sdkperf_java.sh: command not found` -- geen repo-bug,
       zie punt 30 voor de fix (SDKPERF_BIN). ~~Opnieuw draaien.~~ ✅
       Geslaagd: 20 Direct-berichten op STACKIT (GCP-interim) "Try Me!"
       (`enewable/eu/pii/meter/reading`), zichtbaar via de brede
       `enewable/>`-abonnement -- **alle 3 demo-apps nu end-to-end
       bevestigd, elk uitsluitend op de eigen doelbroker.**
     **Les voor de rest van deze sessie:** geen losse `# toelichting`
     meer aan het eind van een commando-regel die Emil moet copy-pasten --
     die toelichting hoort op een eigen regel, of helemaal weg, om dit
     zsh-verschil niet opnieuw te raken.
  30. **`sdkperf_java.sh: command not found` -- Emils eigen omgeving, geen
     repo-bug (Emil, 28/09/2026).** `demo-apps/sdkperf-pii/publish-pii.sh`
     gaat er standaard van uit dat `sdkperf_java.sh` op de PATH staat
     (`: "${SDKPERF_BIN:=sdkperf_java.sh}"`); bij Emil staat het echte
     binary op `/Users/emilzegers/sdkperf/sdkperf-jcsmp-8.4.17.5/sdkperf_java.sh`,
     niet op de PATH. Het script ondersteunt hiervoor al een
     `SDKPERF_BIN`-override, en source't `local-broker/.env` ook al
     automatisch bij elke run (`[[ -f ".../.env" ]] && source ...`) --
     een handmatige `source .env`-stap is dus niet nodig. **Fix:** de
     regel `SDKPERF_BIN=/Users/emilzegers/sdkperf/sdkperf-jcsmp-8.4.17.5/sdkperf_java.sh`
     toegevoegd aan Emils echte (git-genegeerde) `local-broker/.env`, en
     als gedocumenteerd voorbeeld (met de generieke default
     `sdkperf_java.sh`) aan `local-broker/.env.example`. Script simpelweg
     opnieuw draaien; geen andere wijziging nodig. **Bevestigd werkend
     (Emil, 28/09/2026):** het script publiceerde 20 berichten, en deze
     kwamen aan op STACKIT's eigen "Try Me!" op
     `enewable/eu/pii/meter/reading` -- de volledige RDP-exportketen
     werkt dus nu end-to-end voor alle 3 cloud-brokers.
- **Geen automatische provisioning van alle 4 brokers in één commando.**
  Er is bewust voor losse, leesbare stappen gekozen (console + scripts per
  onderdeel) omdat dat beter uit te leggen en te debuggen is vóór een
  live demo dan een enkel "one-click"-script dat bij falen moeilijk te
  doorgronden is. Voor herhaald gebruik na DADD zou een Terraform- of
  Ansible-module (zie `ansible-solace` / de Solace Cloud Terraform provider)
  het geheel herhaalbaarder maken.
- **Geen monitoring/observability** (bijv. dashboards op bridge-doorvoer of
  message-counts) is meegenomen -- voor een live demo is de Broker Manager
  UI voldoende, maar voor een "echt" systeem zou je hier Solace's
  eigen metrics/Prometheus-integratie bij willen.
- **Geen geautomatiseerde tests/CI** voor de configuratiescripts -- gezien
  de aard (infrastructuur-bootstrap voor een eenmalige demo) is dat bewust
  buiten scope, maar voor langduriger gebruik van deze repo is een simpele
  CI-check (bijv. `bash -n` / `shellcheck` / `python -m py_compile` op elke
  push) een kleine, waardevolle toevoeging.
- **Azure = Amerikaanse hyperscaler, ook al staat de data in de EU.** Dit is
  bewust zo gekozen (past bij "niet-persoonlijk mag op een hyperscaler, mits
  EU-gebonden"), maar het is de moeite waard om dit punt in de presentatie
  zelf expliciet te benoemen, gegeven dat slide 2 van de deck juist gaat
  over het CLOUD Act-risico bij Microsoft -- het is een genuanceerd, niet
  triviaal punt en verdient een bewuste zin in de talk, geen automatisme.
- **Geheimenbeheer** is nu simpel (`.env`-bestanden, genegeerd door git).
  Voor een team-repo of langere levensduur zou een echte secrets-manager
  (bijv. 1Password CLI, `sops`, of Solace Cloud's eigen credential-rotatie)
  passender zijn.
- **Geen backup/fallback-materiaal** (schermopname, sheets met screenshots)
  is nog gemaakt -- de presentatie zelf raadt dit expliciet aan
  ("DEMO HOLDER: record a 90-sec fallback clip") en dat geldt evengoed voor
  deze afgeleide demo.
- **Woorddocument-samenvatting** (zie hieronder) is een verdichte versie;
  bij twijfel is dit `PLAN.md`-bestand in de repo altijd de meest actuele en
  volledige bron.

## 14. Vervolgstappen

1. ~~Dit plan doornemen en de STACKIT-beslissing (sectie 4/10) maken.~~ ✅
2. ~~De 3 Solace Cloud-services daadwerkelijk aanmaken.~~ ✅ AWS, Azure en
   STACKIT/GCP-interim staan alle drie op "Running".
3. ~~Bridge-client-username `enewable-local-bridge` aanmaken op elke
   cloud-broker en `configure-local-broker.sh` valideren.~~ ✅ (bridges
   draaien schoon; export via bridges bleek architecturaal niet mogelijk
   zonder reciprocal bridge + publieke bereikbaarheid -- zie sectie 13,
   punten 6-10 -- Emil koos daarom RDP's, zie punt 11 hieronder.)
4. ~~`*_REMOTE_REST_HOST`/`*_REMOTE_REST_PORT` in `local-broker/.env`
   controleren/invullen en `configure-rdp-export.sh` draaien.~~ ✅ -- alle
   3 RDP's zijn geconfigureerd (0 WARN), maar staan in Broker Manager op
   "Down" met HTTP 503 "Service Unavailable" op de queue-binding.
   ~~`test-rest-direct.sh` draaien.~~ ✅ -- alle 3 cloud-brokers
   antwoorden `200 OK` op een directe POST; REST-incoming, auth, host/
   poort en topic-mapping zijn dus uitgesloten als oorzaak. De
   REST-consumer se eigen HTTP-tellers staan echter nog op 0 -- er is nog
   nooit een échte berichtaflevering geprobeerd (zie sectie 13, punt 18).
   Eerste poging tot een echte publish-test liep vast op de stm CLI zelf
   (`stm publish` bestaat niet, moet `stm send` zijn) -- gefixt in
   `demo-apps/stm-public/publish-public.sh` (zie sectie 13, punt 19). Na
   die fix loopt de test meteen vast op een nieuw, apart probleem: de
   lokale broker wijst `pub-public` af met "The RADIUS profile is
   shutdown" -- dit gaat mis vóór de RDP-keten zelfs bereikt wordt, dus
   los van het 503-onderzoek (zie sectie 13, punt 20).
   ~~`diagnose-local-auth.sh` draaien.~~ ✅ -- bevestigt: de
   `enewable`-VPN stond op `authenticationBasicType: "radius"` zonder
   enig RADIUS-profiel; alle client-usernames waren zelf gewoon
   `enabled: true`. Gefixt in `configure-local-broker.sh` (PATCHt nu
   expliciet naar `"internal"`, zie sectie 13, punt 21). **Nu:**
   ~~`configure-local-broker.sh` opnieuw draaien.~~ ✅ -- verbinding werkt
   nu. ~~Publish-test draaien.~~ ✅ (met delivery-mode-fix) -- bericht
   landt eindelijk in de queue (`spooledMsgCount: 10`), maar komt niet
   aan op AWS: de queue-binding postte al die tijd naar het letterlijke,
   niet-geëvalueerde pad `/${topic()}` in plaats van de echte topic,
   vermoedelijk WAF-geblokkeerd (503) -- root cause:
   `requestTargetEvaluation` ontbrak. Gefixt in
   `local-broker/semp/configure-rdp-export.sh` (zie sectie 13, punt 23).
   ~~`configure-rdp-export.sh` opnieuw draaien (patcht de 3 bestaande
   queue-bindings), dan publish-test + `diagnose-rdp.sh` herhalen.~~ ✅ --
   `requestTargetEvaluation: "substitution-expressions"` staat nu
   bevestigd op de broker, maar de 503 en `httpRequestTxMsgCount: 0`
   blijven identiek (ronde 5, `spooledMsgCount` nu 20) -- deze fix was
   dus niet de (enige) oorzaak. Zie sectie 13, punt 24 voor het nieuwe
   spoor (`"lastConnectionFailureReason": "Peer TCP Closed"` op de
   REST-consumer). **Nu:** eerst een publish-test draaien, dan meteen
   ~~`local-broker/semp/watch-rdp-live.sh` draaien.~~ ✅ (poging 1: bug in
   het script, geen info; poging 2: correcte data) -- toont de echte
   root cause: de queue-binding bindt zich nooit aan zijn eigen lokale
   queue (`bindRequestCount: 0`, "Consumers: 0" in Broker Manager), omdat
   het clientprofiel `"default"` (van zowel de RDP als de demo-app
   publishers) `allowGuaranteedMsgReceiveEnabled: false` heeft -- en een
   RDP-binding is precies een guaranteed-receive-operatie. Punt 24's
   `"Peer TCP Closed"`-spoor was een rode haring (zie sectie 13, punt 26).
   **Gefixt:** `configure-rdp-export.sh` maakt nu een los profiel
   `rdp-deliver` (`allowGuaranteedMsgReceiveEnabled: true`) en zet alle
   3 RDP's daarop. ~~Sanity-check: handmatige curl-POST rechtstreeks
   naar AWS.~~ ✅ -- 200 OK, bericht verschijnt meteen in AWS "Try Me!"
   (zie sectie 13, punt 27) -- AWS-kant, credentials en topic-mapping zijn
   dus 100% in orde, het probleem zit uitsluitend lokaal.
   ~~`configure-rdp-export.sh` opnieuw draaien, dan diagnose-rdp.sh en de
   AWS "Try Me!"-tab controleren.~~ ✅✅ **WERKT.** Alle 3 queue-bindings
   `up: true` met `bindSuccessCount: 1`; RDP-aws leverde 21 van de 30
   wachtende berichten daadwerkelijk af (`httpResponseSuccessRxMsgCount:
   21`), en AWS "Try Me!" toont het echte bericht aankomen op
   `enewable/public/market/price` (zie sectie 13, punt 28). De RDP-export
   werkt nu volledig end-to-end voor AWS; Azure/STACKIT staan klaar
   (`up: true`) maar nog ongetest omdat er nog niet op die topics is
   gepubliceerd.
5. Eerste end-to-end testronde volgens sectie 12: publiceren met
   stm/python/sdkperf en in de Solace Cloud console van de DOELBROKER
   controleren dat het bericht op dezelfde topic aankomt, en nergens
   anders. ~~`stm-public/publish-public.sh` -> AWS.~~ ✅ Geslaagd.
   ~~`python-eu-nonpersonal/publisher.py` -> Azure.~~ ✅ Geslaagd (na
   een zsh-commentaar-instructiefout, zie sectie 13 punt 29): 20
   Direct-berichten op `enewable/eu/ops/grid/load`, niets op AWS.
   ~~`sdkperf-pii/publish-pii.sh` -> STACKIT.~~ ✅ Geslaagd -- liep
   eerst vast op `sdkperf_java.sh: command not found` (Emils PATH, geen
   repo-bug), gefixt via `SDKPERF_BIN` in `local-broker/.env` (zie
   sectie 13, punt 30); na de fix: 20 Direct-berichten op STACKIT
   "Try Me!" op `enewable/eu/pii/meter/reading`, niets op AWS/Azure.
   **Alle 3 demo-apps nu end-to-end bevestigd, elk uitsluitend op de
   eigen doelbroker -- de volledige testronde van sectie 12 is
   afgerond.**
6. Draaiboek en fallback-opname voorbereiden (sectie 11, fase 6).
