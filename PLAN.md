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
| Fase 5 -- Demo-apps valideren | ✅✅ 3/3 geslaagd | stm-public (AWS) ✅, python-eu-nonpersonal (Azure) ✅ (na een zsh-commentaar-instructiefout, zie sectie 13 punt 29), sdkperf-pii (STACKIT) ✅ (na een SDKPERF_BIN-fix, zie sectie 13 punt 30) -- volledige testronde afgerond. Sindsdien versterkt (punt 32): elke app publiceert nu alle 3 klassen per invocatie, dus elke app raakt inmiddels alle 3 doelbrokers, niet meer uitsluitend zijn eigen |
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
  Een apart, read-only `monitor`-account (eigen ACL-profiel `acl-monitor`)
  mag op heel `enewable/>` *subscriben* maar helemaal niet publiceren --
  voor visualisatietools zoals Sunburst Topic Explorer, zonder de
  publish-governance van de 3 `pub-*`-accounts te doorbreken.
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
    |-- sample-payloads/               <- gedeeld door alle 3 tools (elk publiceert alle 3 klassen)
    |   |-- public.json
    |   |-- eu-ops.json
    |   `-- eu-pii.json
    |-- stm-public/
    |   |-- README.md
    |   `-- publish-public.sh
    |-- python-eu-nonpersonal/
    |   |-- README.md
    |   |-- publisher.py
    |   |-- requirements.txt
    |   `-- .env.example
    `-- sdkperf-pii/
        |-- README.md
        `-- publish-pii.sh
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
| 4 | Lokale broker + RDP-export | ✅✅ Volledig werkend, end-to-end bevestigd op alle 3 cloud-brokers (AWS, Azure, STACKIT/GCP-interim) | Fase 5 afgerond: volledige testronde met alle 3 demo-apps (stm/python/sdkperf) op alle 3 topic-subtrees, 3/3 geslaagd. Volgende: sectie 14, stap 7 (draaiboek + fallback-opname) |
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
   **Verplaatst naar "Kan na DADD" (Emil, 02/10/2026, zie punt 47) -- geen
   blocker voor DADD zelf.**
6. Herstart de lokale broker-container en herhaal `configure-local-broker.sh`
   + `configure-rdp-export.sh` → opnieuw idempotent te draaien zonder
   handmatige opschoning.
7. Meet de tijd van "koude start" (docker run tot alle 3 RDP's Up) -- moet
   ruim binnen de gewenste ~5 minuten passen; zo niet, overweeg de
   cloud-brokers al vooraf "warm" te laten draaien en alleen de lokale
   broker + RDP's als het live-onderdeel te zien. **Niet meer relevant
   (Emil, 02/10/2026, zie punt 47): op de dag zelf start Emil met een al
   "warme" omgeving (cloud-brokers al deployed/running).**

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
  31. **Documentatie-synchronisatiecheck + README herschreven + nieuw
     doorlopend-draaien-script (Emil, 28/09/2026).** Op verzoek: de code
     (scripts) is als leidend genomen en elk document is daar tegen
     gecontroleerd, in plaats van andersom. Gevonden en gecorrigeerd:
     - `docs/topologie.md` verwees nog naar een niet-bestaande
       `bridge-naam (bridge-to-stackit)` in de STACKIT-interim-uitleg --
       dit moet `rdp-stackit` zijn (bridges zijn al eerder vervangen door
       RDP's, maar deze ene regel was toen gemist). Gefixt.
     - `docs/lokale-broker.md`, sectie "Bekende risico's": twee bullets
       waren achterhaald -- "REST-host/poort nog te bevestigen" (inmiddels
       lang bevestigd én bewezen werkend end-to-end, zie punt 28-30) en
       "TLS-vertrouwen" verwees nog naar de afgeschafte bridges als
       "actueel risico". Beide herschreven naar de huidige, bevestigde
       stand van zaken. Ook een nieuwe sectie "✅ Eindresultaat"
       toegevoegd die de punten 27-30 (AWS-sanity-check, volledige
       end-to-end-bevestiging, Azure/STACKIT-succes, SDKPERF_BIN-fix)
       samenvat -- dit document stopte voorheen bij punt 26 (de
       `rdp-deliver`-fix) en liet niet zien dat de RDP-export daarna
       daadwerkelijk end-to-end werkend is bevestigd.
     - `cloud-setup/aws-us-east/README.md`,
       `cloud-setup/azure-west-europe/README.md` en
       `cloud-setup/gcp-europe-west1-interim/README.md`: elk had nog een
       "Nog te doen"-punt "REST-poort nog te bevestigen" openstaan --
       inmiddels bevestigd én bewezen door de geslaagde end-to-end-test
       per broker. Gefixt, met een concrete verwijzing naar het bewijs
       (aantal afgeleverde berichten, topic, "Try Me!").
     - Geen dode/ongebruikte scripts of bestanden gevonden: de eerder
       afgeschafte bridge-scripts (`diagnose-bridges.sh`,
       `test-reciprocal-bridge-aws.sh`) waren al in een eerdere sessie
       verwijderd (zie punt 12); `git ls-files` bevestigt dat elk
       getrackt bestand nog ergens vandaan wordt verwezen.
     `README.md` is herschreven van een korte verwijzing naar `PLAN.md`
     naar een volledige stap-voor-stap-handleiding om de demo vanaf nul
     te draaien (vereisten, `.env` invullen, lokale broker starten/
     configureren, RDP-export, elke demo-app installeren/draaien/
     verifiëren, troubleshooting) -- uitgaand van reeds bestaande Solace
     Cloud-services en -credentials (het aanmaken daarvan blijft bewust
     buiten scope, zie `cloud-setup/`).
     Nieuw: `local-broker/scripts/run-demo-loop.sh` -- roept de 3
     bestaande publish-scripts (stm/python/sdkperf) herhaald aan, standaard
     elke 30 seconden een nieuwe cyclus (of direct na elkaar met
     `--interval 0`), zodat alle 3 cloud "Try Me!"-tabs doorlopend verse
     data tonen zonder handmatig ingrijpen (bijv. voor een stand/booth).
     Faalt één app (bijv. SDKPerf niet gevonden), dan gaat de cyclus door
     met de andere twee -- bevestigd via een testrun in de sandbox (waar
     geen van de 3 apps kan slagen, maar de cyclus toch netjes alle 3
     probeert en een samenvatting print bij het stoppen). Bewust GEEN
     bash associative arrays gebruikt (zelfde macOS-bash-3.2-reden als
     `configure-local-broker.sh`, zie punt 5).
  32. **Elke demo-app publiceert nu alle 3 dataklassen, niet meer maar
     één (Emil, 28/09/2026, op verzoek).** Voorheen publiceerde elke tool
     structureel maar één klasse (stm -> publiek, python -> niet-persoonlijk
     EU, sdkperf -> PII), wat de indruk kon wekken dat de *tool* de
     bestemming bepaalt. Op Emils voorstel is dit versterkt: alle 3
     demo-apps publiceren nu **standaard alle 3 dataklassen** binnen één
     invocatie, elke klasse met zijn eigen, al bestaande ACL-gescoped
     client-username (`pub-public`/`pub-eu-ops`/`pub-eu-pii`) en eigen
     topic -- zodat overtuigend blijkt dat uitsluitend de topic (en de
     bijbehorende identiteit) de bestemming bepaalt, ongeacht welke tool
     of bron het bericht publiceert. Concreet:
     - Nieuwe map `demo-apps/sample-payloads/` (`public.json`, `eu-ops.json`,
       `eu-pii.json`) vervangt de 2 losse per-app `sample-payload.json`-
       bestanden (verwijderd uit `stm-public/` en `sdkperf-pii/`) -- gedeeld
       door alle 3 tools, één voorbeeldbericht per dataklasse.
     - `stm-public/publish-public.sh`, `python-eu-nonpersonal/publisher.py`
       en `sdkperf-pii/publish-pii.sh` zijn herschreven: elk doorloopt
       standaard alle 3 klassen (eigen credential + eigen topic + eigen
       payload per klasse); een nieuwe `--class public|eu-ops|eu-pii`-vlag
       beperkt een run tot één klasse, voor wie het oorspronkelijke
       één-op-één-scenario nog eens wil laten zien.
     - **Ontwerpfout zelf gevonden vóór het testen, en gefixt:** de eerste
       versie van alle 3 scripts stopte de hele run zodra de EERSTE klasse
       faalde (`set -euo pipefail` in bash, geen exception-afvang in
       Python) -- dat zou het hele punt van deze wijziging ondermijnen
       (nooit bewijzen dat de andere 2 klassen ook werken als de eerste
       toevallig faalt). Gefixt met per-klasse foutisolatie: bash gebruikt
       nu `set -uo pipefail` (zonder `-e`) plus een `try_class()`-wrapper
       die een falende klasse als WARN logt en doorgaat naar de volgende;
       Python vangt exceptions per klasse in de `for`-loop af, logt een
       WARN en gaat door, met `sys.exit(1)` aan het eind als er één
       mislukte. Bevestigd via echte dry-runs in de sandbox (inclusief het
       daadwerkelijk installeren van `solace-pubsubplus` om een reëel
       connectiepoging-gedrag te krijgen tegen een afwezige broker): alle
       3 klassen worden nu onafhankelijk geprobeerd, in alle 3 scripts, en
       `--class eu-pii` beperkt terecht tot precies die ene klasse.
       **Niet in deze sandbox geverifieerd:** de nieuwe `sdkperf`
       `-mf=<bestand>`-vlag (echte JSON-payload uit een bestand versturen,
       in plaats van de oude `-msa=200`-auto-gegenereerde vulbytes) --
       geen live broker beschikbaar om dit tegen te draaien; expliciet als
       zodanig gemarkeerd in het scriptcommentaar.
     - `python-eu-nonpersonal/.env.example` uitgebreid met
       `PUB_PUBLIC_USER`/`PUB_PUBLIC_PASSWORD` en
       `PUB_EU_PII_USER`/`PUB_EU_PII_PASSWORD` (voorheen alleen
       `PUB_EU_OPS_*`) -- deze ene app heeft nu alle 3 credential-sets
       nodig.
     - `local-broker/scripts/run-demo-loop.sh` ongewijzigd qua logica
       (was al voorbereid op scripts die zelf meerdere klassen afhandelen)
       -- alleen het headercommentaar bijgewerkt: elke cyclus is nu 9
       klasse-runs (3 tools x 3 klassen), en `--count N` geldt per klasse,
       niet per script. Bevestigd via
       `./local-broker/scripts/run-demo-loop.sh --once --count 1` dat de
       twee foutisolatie-niveaus (per klasse binnen een app, per app
       binnen een cyclus) samen correct werken.
     - Documentatie bijgewerkt om dit weer te geven: `demo-apps/README.md`
       (nieuwe uitleg "zelfde tool, drie bestemmingen" + klasse-tabel +
       `--class`-vlag), de 3 per-app `README.md`'s, `docs/demo-apps.md`
       ("Eén tool, drie bestemmingen" als hoofdscenario; de oorspronkelijke
       3-apps-los-draaien-aanpak als optionele stap 2, om te laten zien
       dat het geen toevalstreffer van één tool is), `docs/topologie.md`
       (diagram: geen klasse-specifiek label meer per tool -- alle 3 tools
       zien nu identiek uit in het diagram, met een nieuwe alinea die
       uitlegt waarom -- én de `classDef`-kleurtoewijzing gecorrigeerd:
       voorheen kregen `STM`/`PY`/`SDK` nog een klasse-kleur, wat na deze
       wijziging misleidend was geworden; nu krijgen alleen de 3
       cloud-brokers nog een klasse-kleur), `topology/topologie.mmd`
       (zelfde diagram-aanpassing, 1-op-1 gesynchroniseerd met
       `docs/topologie.md`), en het root-`README.md` (architectuurdiagram,
       inleidende alinea, stap 5 en stap 6 herschreven: één script draaien
       raakt nu alle 3 cloud-brokers, dus stap 6 verifieert nu alle 3
       tegelijk in plaats van één broker per app-run).
     `PLAN.md`'s directory-boom (sectie 9) bijgewerkt: de 2 verwijderde
     per-app `sample-payload.json`-bestanden vervangen door de nieuwe
     gedeelde `demo-apps/sample-payloads/`-map.
  33. **`run-demo-loop.sh`-opties met concrete voorbeelden in README.md
     (Emil, 28/09/2026, op verzoek).** De opties (`--interval`, `--count`,
     `--once`) stonden al volledig uitgelegd in het script se eigen
     `--help`, en README.md stap 7 verwees daar al naar -- maar zonder
     kant-en-klare voorbeeldcommando's. Toegevoegd aan stap 7: expliciete
     voorbeelden voor een ander interval, direct-achter-elkaar (`--interval
     0`), een vast berichtaantal per klasse (`--count`, te combineren met
     `--interval`), en één losse testcyclus (`--once --count 1`) -- zodat
     deze direct te kopiëren zijn zonder eerst `--help` te moeten
     raadplegen.
  34. **Read-only `monitor`-account voor Sunburst Topic Explorer (Emil,
     28/09/2026, op verzoek).** Emil wil
     [Sunburst Topic Explorer](https://explorer.solace.dev/) gebruiken om
     het berichtenverkeer op de `enewable`-VPN live te visualiseren; hij
     kan al met `default`/`default` verbinden met de broker se ingebouwde
     `default`-VPN, maar die combinatie bestaat niet op `enewable` --
     geen van de 3 bestaande `pub-*`-client-usernames kan hier ook maar
     voor dienen, want hun ACL-profiel heeft
     `subscribeTopicDefaultAction: disallow` zonder enige subscribe-
     exceptie (ze zijn bewust publish-only, zie sectie 8). Nieuw, apart
     client-username `monitor` toegevoegd in `configure-local-broker.sh`
     (stap 3 van dat script) met een eigen ACL-profiel `acl-monitor`:
     `publishTopicDefaultAction: disallow` (kan zelf niets publiceren) en
     `subscribeTopicDefaultAction: disallow` met precies één exceptie,
     `enewable/>` (mag alles onder de VPN's eigen topic-boom volgen). Dit
     doorbreekt de publish-governance van de 3 bestaande accounts niet --
     het is een puur read-only, apart identiteitstype. Credentials
     (`MONITOR_USER`/`MONITOR_PASSWORD`, default `monitor`/`monitor-pw`)
     toegevoegd aan `local-broker/.env.example`. Connectiegegevens voor
     Sunburst: `ws://localhost:8008` (dezelfde web-messaging-poort als
     `stm`), VPN `enewable`, username/password zoals hierboven --
     gedocumenteerd in `README.md`, nieuwe stap 8 "Verkeer visualiseren
     met Sunburst Topic Explorer". **Bevestigd door Emil (28/09/2026):**
     verbinden met VPN `enewable` + username/password `monitor` lukt, maar
     "Start/Subscribe" gaf eerst "Subscription ACL Denied on Topic:
     #noexport/>" -- geen ACL-bug: Sunburst vult het "Topic(s)"-veld
     standaard met `#noexport/>, #noexport/#P2P/>` (een intern
     Solace-topicprefix, los van onze demo-data), en dat topic zit terecht
     niet in `acl-monitor`'s enige subscribe-exceptie (`enewable/>`). Geen
     scriptwijziging nodig -- oplossing is het "Topic(s)"-veld in Sunburst
     zelf aanpassen naar `enewable/>` vóór het (opnieuw) klikken op
     "Start/Subscribe". `README.md`, sectie "Verkeer visualiseren",
     uitgebreid met deze toelichting.
  35. **`-mf` was geen echte SDKPerf-vlag -- gefixt naar `-pal` (Emil,
     28/09/2026, bevestigd door een echte fout tegen SDKPerf 8.4.17.5).**
     Punt 32 markeerde de `-mf`-vlag in `sdkperf-pii/publish-pii.sh`
     expliciet als "niet in deze sandbox geverifieerd" -- terecht: Emil
     kreeg `Parsing failed. Reason: Unrecognized option: -mf` in de
     praktijk. `-mf` bestaat niet in SDKPerf; de officiële
     command-line-referentie kent alleen `-msa` (auto-gegenereerde
     vulbytes) voor payload-grootte, geen vlag voor payload uit een
     bestand. Uitgezocht via de Solace-communitythread "sdkperf file
     input format": de juiste vlag is `-pal=<bestand>`
     (payload-attachment-list) -- stuurt de ruwe inhoud van het bestand
     als binary attachment, precies wat we willen voor
     `../sample-payloads/<class>.json` (in tegenstelling tot `-sdm`, dat
     een apart, getypeerd structured-data-formaat verwacht, niet ruwe
     JSON). Gefixt in `demo-apps/sdkperf-pii/publish-pii.sh` (alle 3
     `publish_class()`-aanroepen) en in
     `demo-apps/sdkperf-pii/README.md`'s handmatige voorbeeldcommando.
     **Nog niet opnieuw end-to-end bevestigd** met een echte broker na
     deze fix (dat vereist een volgende testronde door Emil); wel
     bevestigd dat `-pal` de door de Solace-community gedocumenteerde,
     juiste vlag is voor dit doel.
  36. **Dynamische topics: veldwaarden uit het bericht toegevoegd aan de
     topic (Emil, 28/09/2026, op verzoek).** Op verzoek: elke topic krijgt
     nu extra niveaus met echte veldwaarden uit het bericht zelf, in
     plaats van een vaste string:
     - `enewable/public/market/price` -> `.../price/<type>/<market>`
       (bijv. `.../price/day-ahead-price/NL`).
     - `enewable/eu/ops/grid/load` -> `.../load/<type>/<postcodeArea>`
       (bijv. `.../load/grid-load-aggregate/3500-NL`).
     - `enewable/eu/pii/meter/reading` -> `.../reading/<customerId>`
       (bijv. `.../reading/ENW-NL-000482`).
     Dit vereist GEEN wijziging aan de broker-configuratie: alle 3
     ACL-publishTopicExceptions (`configure-local-broker.sh`) en alle 3
     RDP-export-queue-subscriptions (`configure-rdp-export.sh`) staan al
     op de hele `enewable/<klasse>/>`-subtree (multi-level wildcard), niet
     op een exacte topic -- extra niveaus erbij vallen er automatisch
     onder. Ook mooi bijeffect: in Sunburst Topic Explorer (punt 34) krijgt
     elke klasse nu zichtbaar meerdere takken in de topic-boom in plaats
     van telkens exact dezelfde ene topic.
     - `stm-public/publish-public.sh` en `sdkperf-pii/publish-pii.sh`
       (beide lezen een STATISCH JSON-bestand uit `sample-payloads/`):
       nieuwe `json_field()`-helper leest het gevraagde veld uit dat
       bestand -- gebruikt `jq` als dat geïnstalleerd is (zie README.md,
       "Vereisten"), anders een plain grep/sed-fallback (deze JSON-
       bestanden zijn plat, geen geneste objecten/arrays, dus dat volstaat).
       Elke `run_*()`-functie bouwt zijn topic nu op met die veldwaarden
       vóór het aanroepen van `publish_class()`.
     - `python-eu-nonpersonal/publisher.py` (bouwt elk bericht dynamisch in
       code, met `postcodeArea`/`customerId` die per bericht rouleren uit
       een vaste lijst): de topic wordt nu PER BERICHT opgebouwd, binnen de
       publicatielus, in plaats van één keer buiten de lus -- want de
       veldwaarden verschillen per bericht. `CLASSES` kreeg een extra
       `topic_fields`-lijst per klasse (`["type","market"]`,
       `["type","postcodeArea"]`, `["customerId"]`).
     **Bevestigd via echte dry-runs** (geen live broker nodig voor deze
     specifieke test): `json_field()` getest tegen de 3 echte
     `sample-payloads/*.json`-bestanden, zowel met `jq` als via de
     grep/sed-fallback (beide geven identieke, juiste waarden); de 2
     bash-scripts getest met een gestubde `publish_class()` (bevestigt de
     exacte topic-string die aan `publish_class()` wordt doorgegeven,
     inclusief `--class`-filtering); `publisher.py`'s topic-opbouwlogica
     los getest (3x per klasse, bevestigt dat de topic per bericht
     meevarieert met `postcodeArea`/`customerId`). `bash -n` en
     `python -m py_compile` op de definitieve versies: allemaal ok.
  37. **Publiek-klasse: meer variatie in `<type>`/`<market>` (Emil,
     28/09/2026, op verzoek).** Punt 36's publiek-topic varieerde nog maar
     op precies 1 vaste combinatie (`day-ahead-price`/`NL`, uit het
     statische `public.json`) -- geen echte variatie. Uitgebreid naar 3
     realistische type-waarden (`day-ahead-price`, `intraday-price`,
     `imbalance-price`) en de 5 gevraagde markten (`NL`, `BE`, `LU`, `DE`,
     `FR`), willekeurig gekozen PER BERICHT:
     - `python-eu-nonpersonal/publisher.py`: nieuwe `PRICE_TYPES`/
       `MARKETS`-lijsten (zelfde stijl als de al bestaande
       `POSTCODE_AREAS`/`CUSTOMER_IDS`); `make_public_message()` gebruikt
       nu `random.choice()` voor `type`/`market` i.p.v. de vaste strings
       `"day-ahead-price"`/`"NL"`. Geen verdere wijziging nodig -- deze
       velden vloeiden al automatisch door naar de topic (punt 36's
       per-bericht topic-opbouw).
     - `stm-public/publish-public.sh` en `sdkperf-pii/publish-pii.sh`
       (beide publiceren `eu-ops`/`eu-pii` nog steeds als één STATISCHE
       batch uit `sample-payloads/*.json`, maar `public` moest nu WEL
       variëren): nieuwe `TYPES_PUBLIC`/`MARKETS_PUBLIC`-arrays (plain
       indexed arrays, geen `declare -A`, dus macOS-bash-3.2-veilig) en
       een nieuwe `render_payload()`-helper die `public.json` per bericht
       kopieert met `type`/`market` overschreven (via `jq`, of een
       sed-fallback zonder `jq`). `run_public()` is herschreven van één
       aanroep naar een lus van COUNT iteraties, elk met een eigen
       willekeurige `type`/`market`, eigen topic, eigen gerenderd
       payload-bestand, en `-mn=1`/`--count 1` (nieuwe 6e parameter op
       `publish_class()`, met de globale `COUNT` als default zodat
       `eu-ops`/`eu-pii` ongewijzigd blijven werken). **Bewuste
       performance-afweging**: dit roept `stm`/`sdkperf_java.sh` nu COUNT
       keer LOS aan voor de publiek-klasse (proces-opstart per bericht)
       i.p.v. één batch-aanroep -- merkbaar trager dan `eu-ops`/`eu-pii`,
       vooral bij SDKPerf's JVM-opstarttijd. Gedocumenteerd in
       `docs/demo-apps.md`'s Timing-sectie: gebruik `--class public 5` (of
       vergelijkbaar) tijdens de live demo om dit voorspelbaar kort te
       houden.
     **Bevestigd via echte dry-runs** (nep-`stm`/nep-`sdkperf_java.sh`-
     scripts die topic + payload-inhoud teruggeven i.p.v. een echte
     broker aan te spreken): voor beide bash-scripts getest, ZOWEL met
     `jq` beschikbaar ALS met een PATH die `jq` daadwerkelijk uitsluit
     (bevestigd met `command -v jq` vóór en na het beperken van de PATH)
     -- beide paden geven de juiste, overschreven `type`/`market` in topic
     én payload terug, over meerdere/alle 3 klassen heen, inclusief
     `--class`-filtering. `publisher.py`'s `make_public_message()` los
     getest over 30 aanroepen: alle 3 types en alle 5 markten kwamen voor.
     `bash -n` en `python -m py_compile` op de definitieve versies:
     allemaal ok.
  38. **Eu-ops/eu-pii: meer variatie in `<postcodeArea>`/`<customerId>`
     (Emil, 28/09/2026, op verzoek).** Punt 36's `eu-ops`/`eu-pii`-topics
     varieerden nog op maar 4 resp. 3 vaste waarden (uit de statische
     `sample-payloads/*.json`-bestanden) -- geen echte variatie, en veel
     minder dan punt 37 net had toegevoegd voor `public` (3 x 5 = 15
     combinaties). Uitgebreid naar 10 `postcodeArea`-waarden voor eu-ops
     (`1000-NL`, `2000-NL`, `3500-NL`, `4000-NL`, `5600-NL`, `6500-NL`,
     `7500-NL`, `8000-NL`, `9000-NL`, `9700-NL`) en 20 fictieve
     `customerId`-waarden voor eu-pii (`ENW-NL-000482` t/m
     `ENW-NL-010799`, oplopende gefingeerde klantnummers), willekeurig
     gekozen PER BERICHT:
     - `python-eu-nonpersonal/publisher.py`: `POSTCODE_AREAS`/
       `CUSTOMER_IDS`-lijsten uitgebreid van 4/3 naar 10/20 waarden
       (zelfde `random.choice()`-mechanisme als al gebruikt; geen verdere
       codewijziging nodig).
     - `stm-public/publish-public.sh` en `sdkperf-pii/publish-pii.sh`
       (deze publiceerden `eu-ops`/`eu-pii` tot nu toe nog als één
       STATISCHE batch uit `sample-payloads/*.json`, in tegenstelling tot
       `public`, dat punt 37 al per bericht liet variëren): dezelfde
       aanpak als punt 37 nu ook toegepast op `eu-ops`/`eu-pii` --
       nieuwe `POSTCODE_AREAS_EU_OPS`/`CUSTOMER_IDS_EU_PII`-arrays (plain
       indexed arrays), en `run_eu_ops()`/`run_eu_pii()` herschreven van
       één aanroep naar een lus van COUNT iteraties, elk met een eigen
       willekeurige `postcodeArea`/`customerId`, eigen topic (via
       `render_payload()`, al geïntroduceerd in punt 37), en `-mn=1`/
       `--count 1` per bericht. Voor eu-ops blijft `type` een vast veld
       (gelezen met `json_field()`, want dat veld varieert bij deze
       klasse niet). **Gevolg**: ALLE 3 klassen roepen `stm`/
       `sdkperf_java.sh` nu COUNT keer los aan per klasse (was: alleen
       `public`) -- een default-run is dus tot 3x zoveel proces-
       aanroepen als vóór punt 37 (bijv. 60 voor SDKPerf's default
       COUNT=20 i.p.v. 20). `docs/demo-apps.md`'s Timing-sectie is
       hierop aangepast: het advies om `COUNT` laag te houden voor de
       live demo geldt nu voor de hele run, niet meer alleen voor
       `--class public`.
     **Bewuste veiligheidskeuze (ongewijzigd van punt 37)**: geen
     poging om SDKPerf's `-ptl=lijst`/`-pal=lijst`-stijl comma-
     separated cycling te proberen (ook al accepteert `-ptl` officieel
     lijsten) -- `-pal` zelf is niet officieel gedocumenteerd (alleen via
     een community-thread gevonden, zie punt 35), en na de eerdere
     `-mf`-misser leek de al-geverifieerde per-bericht-lus-aanpak
     veiliger dan een ongeteste aanname.
     **Bevestigd via echte dry-runs** (dezelfde nep-`stm`/
     nep-`sdkperf_java.sh`-scripts als punt 37): `stm-public/
     publish-public.sh` getest met een fake `stm`-binary -- alle 10
     distincte `postcodeArea`-waarden en alle 20 distincte
     `customerId`-waarden kwamen voor over resp. 30- en 60-berichten-
     runs, zowel met `jq` beschikbaar als via de grep/sed-fallback (apart
     getest met een PATH die `jq` daadwerkelijk uitsluit, gecontroleerd
     met `command -v jq`). `sdkperf-pii/publish-pii.sh` identiek getest
     met een fake `sdkperf_java.sh`-binary -- zelfde resultaat (10/20
     distincte waarden, beide fallback-paden, gecombineerde run van alle
     3 klassen werkt). `python-eu-nonpersonal/publisher.py`'s uitgebreide
     lijsten gecontroleerd via `python -m py_compile`. `bash -n` op beide
     bash-scripts: allemaal ok.
  39. **`TODO.md`, `AGENTS.md`, `SKILLS.md` toegevoegd (Emil, 28/09/2026,
     op verzoek).** Op verzoek: de 12 prioriteitspunten uit de laatste
     sessie-samenvatting (voortbouwend op deze sectie 13 en op sectie 10/
     12/14) zijn omgezet naar een los, actiegericht `TODO.md` in de
     repo-root, zodat een sessie gesloten en later hervat kan worden
     zonder eerst dit hele logboek door te moeten. `TODO.md` groepeert de
     punten in "Moet vóór DADD" (draaiboek + fallback-opname; de nieuwe
     variatie-uitbreidingen echt op een cloud-broker bevestigen, niet
     alleen dry-run; STACKIT GA-check; fase 5 herhalen vóór DADD), "Zou
     goed zijn vóór DADD" (negative ACL-test; koude-starttijd meten; Azure-
     hyperscaler en public-clusters expliciet benoemen in de talk), en
     "Kan na DADD" (provisioning-automatisering, monitoring, CI,
     secretsbeheer, DMR-cluster voor `#noexport`) -- elk item met een
     verwijzing naar het bijbehorende punt hier in `PLAN.md`.
     Daarnaast, zoals gevraagd: gecontroleerd of er verder nog losse
     TODO's/open acties in code of configuratie stonden (`git grep` op
     `TODO|FIXME|XXX|HACK` over alle getrackte `.sh`/`.py`/`.json`/
     `.env*`-bestanden) -- geen treffers buiten wat al in `TODO.md` staat.
     `local-broker/.env` vergeleken met `local-broker/.env.example`: alle
     42 sleutels aanwezig, elk met een echte (niet-placeholder) waarde.
     De twee andere `.env.example`-bestanden
     (`demo-apps/python-eu-nonpersonal/`, `cloud-setup/solace-cloud-api/`)
     hebben bewust geen eigen `.env`: het Python-script valt automatisch
     terug op `local-broker/.env`, en het Solace-Cloud-API-`.env` is alleen
     nodig voor `create-service.sh` (fase 2/3, al afgerond) -- geen van
     beide is dus een gat.
     Verder toegevoegd: `AGENTS.md` (architectuurfeiten en werkconventies
     voor een AI-coding-agent of nieuwe bijdrager -- o.a. het
     wildcard-topic-subtree-patroon, de macOS-bash-3.2-beperking, en de
     documentatie-/commit-conventie die deze sectie 13 zelf illustreert)
     en `SKILLS.md` (herbruikbare recepten: dry-run-testmethode zonder
     live broker, de no-jq-fallback-testmethode, correcte
     SDKPerf-vlaggen, de Sunburst-Topic(s)-veld-gotcha, het
     docx-herbouwrecept). `README.md` kreeg een nieuwe sectie "Sessie
     hervatten / werken met een AI-coding-agent aan deze repo" die uitlegt
     hoe deze 3 bestanden samen met `PLAN.md` te gebruiken zijn.
  40. **De 3 cloud-broker services zijn verwijderd; opnieuw aangemaakt via
     Terraform, in twee organisaties (Emil, 01/10/2026, op verzoek).** De
     3 Solace Cloud event broker services (AWS, Azure, STACKIT/interim)
     uit fase 3 bestaan niet meer. Nieuwe opzet, op verzoek: "Developer
     100"-tier (i.p.v. de eerdere Enterprise-250-HA-klasse) en verdeeld
     over TWEE Solace Cloud-organisaties -- AWS + Azure in de ene org,
     STACKIT in de andere -- in plaats van één org voor alles zoals
     voorheen. Op verzoek automatisch aangemaakt met Terraform i.p.v. de
     console/`create-service.sh`-REST-route.
     **Onderzoek**: Solace heeft een eigen, BETA Terraform-provider voor
     Mission Control (`SolaceProducts/terraform-provider-solacecloud`,
     resource `solacecloud_service`, zie de
     [Solace Community-aankondiging](https://community.solace.com/t/new-beta-solace-cloud-terraform-provider-for-managing-event-broker-services/4502)
     en de [Terraform Registry](https://registry.terraform.io/providers/SolaceProducts/solacecloud/latest)) --
     dit beheert uitsluitend de SERVICE zelf (Mission Control-niveau), niet
     de SEMP-objecten erbinnen (die blijven, net als voorheen,
     `configure-remote-bridge-users.sh`'s taak). Provider-configuratie
     vereist per org een eigen `api_token` EN een eigen `base_url`
     (Home-Cloud-afhankelijk, niet per se hetzelfde voor beide org's) --
     opgelost met 2 `provider "solacecloud"`-blokken met een `alias`.
     **Onzekerheid, expliciet niet blindelings aangenomen** (zelfde
     voorzichtigheid als bij `-mf` destijds, zie punt 35): bronnen
     spreken elkaar tegen over de exacte schrijfwijze van de
     "Developer 100"-`service_class_id` (REST-API-docs: `"developer"`
     kleine letters; Terraform-provider-schema: default `"DEVELOPER"`
     hoofdletters) -- `variables.tf` gebruikt voorlopig `"DEVELOPER"` met
     een expliciete waarschuwing om dit via `terraform plan` of de
     `missionControl/serviceClasses`-endpoint te bevestigen vóór apply.
     Ook niet aangenomen: of STACKIT inmiddels echt als eigen
     datacenter-optie beschikbaar is (zie de al bestaande "STACKIT
     GA-check" in `TODO.md`) -- `datacenter_id_stackit` is een losse
     variabele die naar de echte STACKIT-id of (net als voorheen) een
     GCP-europe-west1-interim-id kan wijzen, Emil's keuze na het zelf
     opzoeken.
     **Nieuwe bestanden** (geen bestaande scripts overschreven, zoals
     gevraagd): `cloud-setup/terraform/{provider,variables,main,outputs}.tf`,
     `terraform.tfvars.example`, en een `README.md` met de volledige
     stappen (incl. de netwerktoegang-beperking hieronder) en de
     vervolgstappen na `apply` (uitlezen van de gegenereerde
     SEMP-credentials uit de Terraform-output, `local-broker/.env`
     bijwerken, de bestaande SEMP-configuratiescripts opnieuw draaien,
     testplan sectie 12 herhalen).
     **Netwerktoegang**: zoals al vastgesteld voor `create-service.sh`
     (zie `docs/cloud-brokers.md`, "Netwerktoegang vanuit deze sessie"),
     is `api.solace.cloud` niet bereikbaar vanuit deze sessie (noch de
     cloud-container, noch de sandbox-VM) -- `terraform init`/`plan`/
     `apply` moet dus door Emil zelf in zijn eigen terminal gedraaid
     worden; de assistent kan de configuratie voorbereiden maar niet
     uitvoeren of verifiëren tegen de echte API.
     `TODO.md` kreeg een nieuwe, blokkerende sectie bovenaan ("eerst dit")
     en `cloud-setup/README.md` een statusmelding die naar de nieuwe
     Terraform-route verwijst; de bestaande console-/REST-route blijft
     staan als handmatig alternatief/fallback (de provider is beta).
  41. **`terraform.tfvars` deels ingevuld; Terraform-CLI-installatie liep
     meteen vast; werkwijze aangepast naar één stap tegelijk (Emil,
     01/10/2026).** AWS/Azure-org blijft ongewijzigd (bevestigd door
     Emil), dus `aws_azure_org_api_token` in `terraform.tfvars` (nieuw
     aangemaakt uit `terraform.tfvars.example`) rechtstreeks gevuld met de
     inhoud van `token-dadd-2026.txt`, bestand-naar-bestand -- de waarde
     is nergens in de chat getoond. Bevestigd dat `terraform.tfvars` door
     `.gitignore` wordt genegeerd (`git check-ignore -v`). Opnieuw
     bevestigd (curl vanuit de sessie): `api.solace.cloud` blijft 403
     geblokkeerd, dus ook de losse datacenter-/serviceClasses-lookups en
     `terraform init/plan/apply` moeten door Emil zelf.
     **Eerste concrete stap faalde**: `brew install terraform` geeft
     `Warning: No available formula with the name "terraform"` --
     HashiCorp's Terraform-formule is uit homebrew-core verwijderd sinds
     de overstap naar de BUSL-licentie; moet via HashiCorp's eigen tap
     (`brew install hashicorp/tap/terraform`). Gedocumenteerd in
     `SKILLS.md`, "Terraform CLI installeren op macOS (Homebrew)".
     **Werkwijze aangepast, op verzoek**: bij dit soort stapsgewijze,
     door Emil zelf uit te voeren procedures (installaties, `terraform
     apply`, console-acties) geeft de assistent voortaan ÉÉN instructie
     tegelijk en wacht terugkoppeling af vóór de volgende stap, i.p.v.
     een hele stappenlijst vooruit -- precies omdat de eerste stap hier al
     fout bleek. Vastgelegd in `AGENTS.md`, "Stapsgewijze procedures". Bijvangst: de
     voorgestelde `terraform version   # >= 1.5 verwacht`-regel had zelf
     een inline `#`-commentaar (dezelfde, al in `README.md` gedocumenteerde
     zsh-valkuil) en liet daardoor een leeg `=`-bestand in de repo-root
     achter (opgeruimd); vastgelegd als extra regel in `AGENTS.md`: nooit
     een inline `#`-commentaar op een regel die Emil moet kopiëren-plakken.

  42. **De 3 services succesvol aangemaakt met Terraform; `local-broker/.env`
     volledig bijgewerkt (Emil + assistent, 02/10/2026).** Stapsgewijs (zie
     punt 41) de resterende invoer verzameld: STACKIT-org blijkt een eigen
     console/API-domein te hebben (`staging-console.maasgo.net` /
     `staging-api.maasgo.net`, i.p.v. `*.solace.cloud`) -- ontdekt via de
     DevTools Network-tab, want niet te raden. De 3 `datacenterId`'s
     opgezocht via `missionControl/datacenters` (token-naar-bestand-script,
     nooit in de chat getoond): `eks-us-east-1a` (AWS), `aks-westeurope`
     (Azure), en een verrassing -- STACKIT heeft inmiddels een **eigen,
     echte `SolaceDedicated`-datacenter** (`stackitdemo-stackit-eu01-production`,
     "StackIT Production Region"), dus geen GCP-interim-stand-in meer nodig
     (de aanname in punt 40/`TODO.md` was voorzichtigheidshalve nog
     interim). Alle drie datacenters tonen `"DEVELOPER"` (hoofdletters) in
     hun `supportedServiceClasses` -- bevestigt definitief de juiste
     schrijfwijze van `service_class_id`, die bij `terraform plan` ook
     zonder validatiefout bleek. `terraform init` + `plan` + `apply`
     (door Emil, eigen terminal) zijn alle drie zonder fouten geslaagd:
     3 services `Running` (AWS id `fagb5x8a2rd`, Azure id `56tdd0ahgcm`,
     STACKIT id `t5ushg0cbk8`), elk met expliciete `message_vpn_name =
     "enewable"` (dus dit keer geen auto-afgekapte VPN-naam-verwarring,
     zie `cloud-setup/terraform/README.md`). `terraform output -json`
     van alle 3 naar het (gitignored) `output/`-folder geschreven en door
     de assistent zelf ingelezen (nooit in de chat geplakt). Daarmee
     `local-broker/.env` bijgewerkt: nieuwe SMF/SEMP-hostnames (let op --
     STACKIT's hostname-domein is `messaging.maasgo.net`, niet
     `messaging.solace.cloud`), alle 3 `*_REMOTE_VPN` naar `enewable`, en
     de 3 nieuwe `*_SEMP_ADMIN_PASSWORD`-waarden (SEMP-manager-credential
     uit de Terraform-output, file-naar-file, nooit getoond). De oude
     `*_BRIDGE_PASSWORD`-waarden horen bij de verwijderde services en zijn
     dus ongeldig -- gezet op een expliciete `CHANGEME`-placeholder totdat
     `configure-remote-bridge-users.sh` (volgende stap) een nieuwe
     bridge-user aanmaakt. `TODO.md`'s blokkerende sectie en
     `cloud-setup/terraform/README.md`'s STACKIT-GA-vraag kunnen hiermee
     als opgelost worden afgevinkt.

  43. **Bug #4 gevonden en gefixt: RDP's bleven naar de OUDE cloud-hosts/
     credentials wijzen na het opnieuw aanmaken van de services (Emil +
     assistent, 02/10/2026).** Na punt 42 (nieuwe services + bijgewerkte
     `.env`) `configure-remote-bridge-users.sh` en `configure-local-broker.sh`
     zonder problemen opnieuw gedraaid, maar `configure-rdp-export.sh` gaf
     voor alle 3 routes "(already exists, skipping)" op de restConsumer-stap
     en een eerste publish-test (`stm-public/publish-public.sh`) liet
     helemaal niets verschijnen op AWS/Azure/STACKIT "Try Me!", ondanks dat
     de lokale publicatie zelf steeds slaagde. Root cause: in
     `local-broker/semp/configure-rdp-export.sh` kreeg de restConsumer-stap
     (in tegenstelling tot queueBindings/restDeliveryPoints/clientProfiles
     hierboven, die allemaal al een onvoorwaardelijke PATCH na de POST
     hadden) nooit die PATCH -- op een rerun bleef een AL BESTAANDE
     restConsumer dus gewoon de OUDE `remoteHost`/`remotePort`/
     credentials van vóór de verwijdering vasthouden, zonder enige
     foutmelding (de POST retourneert gewoon "already exists" en het
     script gaat door). De queue + message-promotion werkten dus prima
     lokaal, maar de RDP kon nooit bij het (inmiddels niet meer bestaande
     of niet meer kloppende) oude eindpunt afleveren. **Gefixt:** een
     onvoorwaardelijke `PATCH` toegevoegd na de restConsumer-POST, exact
     hetzelfde patroon als de 3 andere sub-objecten al hadden -- een
     rerun past nu altijd de actuele host/poort/credentials toe, niet
     alleen bij eerste aanmaak. Nog te doen: Emil moet
     `configure-rdp-export.sh` opnieuw draaien en de publish-test
     herhalen. Aparte, kleinere bijvangst tijdens dezelfde testrun:
     `demo-apps/stm-public/publish-public.sh` faalde op de eu-ops/eu-pii-
     klassen met `mktemp: mkstemp failed ... File exists` (macOS-lokaal,
     stale tmp-bestand in `/var/folders/.../T/`) -- niet onderzocht als
     onderdeel van deze bugfix, nog open.

  44. **Bevestigd: volledige end-to-end-keten werkt weer tegen de nieuwe
     services (Emil, 02/10/2026).** Na de PATCH-fix uit punt 43:
     `configure-rdp-export.sh` opnieuw gedraaid, daarna
     `stm-public/publish-public.sh` nogmaals. Resultaat in de 3 Solace
     Cloud "Try Me!"-tabs: AWS toont de publieke markt-prijsberichten
     (`enewable/public/market/price/...`), Azure toont de niet-persoonlijke
     EU-operationele data (`enewable/eu/ops/grid/load/grid-load-aggregate/
     ...`), en STACKIT toont de gevoelige PII-meterstanden
     (`enewable/eu/pii/meter/reading/...`) -- elk uitsluitend op zijn eigen
     broker, net als vóór de verwijdering. Hiermee is de volledige keten
     (Terraform-services -> .env -> bridge-users -> lokale broker -> RDP-
     export) end-to-end herbevestigd tegen de services die in punt 42 zijn
     aangemaakt. De `mktemp`-WARN uit punt 43 bleek geen blokkade voor
     deze test en blijft een klein, apart openstaand puntje. Openstaand:
     Azure/STACKIT nog los testen met de andere 2 demo-apps
     (python-eu-nonpersonal, sdkperf-pii) en de negative-ACL-test (TODO.md),
     en een volledige testronde vlak vóór DADD zelf herhalen (TODO.md,
     "Moet vóór DADD").

  45. **Bug #5 gevonden en gefixt: `mktemp`-template met een `.json`-staart
     na de `X`'s werd door macOS/BSD's `mktemp` niet gerandomiseerd (Emil +
     assistent, 02/10/2026).** Gevonden via `./run-demo-loop.sh --once`
     (vervolg op punt 44, op Emils verzoek i.p.v. de 2 overige demo-apps
     los testen): `stm-public` faalde op `run_eu_ops`/`run_eu_pii` met
     `mktemp: mkstemp failed on .../enewable-eu-ops.XXXXXX.json: File
     exists`, en `sdkperf-pii` faalde ook. `ls -la` op de TMPDIR bevestigde
     de root cause: er stonden daadwerkelijk bestanden met de LETTERLIJKE
     naam `enewable-eu-ops.XXXXXX.json` (ongesubstitueerde `X`'s) -- macOS'
     `mktemp` randomiseert de `X`'s alleen als ze aan het EINDE van de
     bestandsnaam staan, niet wanneer er nog een `.json`-staart achter
     volgt. Het sjabloon "werkte" dus tot nu toe alleen bij toeval: zolang
     niemand het script halverwege onderbrak (vóór de eigen `rm -f`-
     opruiming), bestond het letterlijke pad nog niet en "slaagde"
     `mktemp` door dat exacte pad gewoon aan te maken -- zonder enige
     echte randomisatie. Bijkomend ontdekt: `stm-public/publish-public.sh`
     EN `sdkperf-pii/publish-pii.sh` gebruikten exact dezelfde letterlijke
     bestandsnamen, dus de twee scripts konden elkaars tijdelijke bestand
     ook nog eens overschrijven/blokkeren. **Gefixt** in beide scripts (6
     plekken): het sjabloon omgedraaid naar `enewable-<klasse>.json.XXXXXX`
     (de `X`'s nu echt aan het eind), wat op zowel BSD- als GNU-`mktemp`
     gegarandeerd wél randomiseert -- niets anders in de code leunt op de
     exacte bestandsnaam of -extensie (alleen als ondoorzichtig pad
     doorgegeven aan `stm --file`/`sdkperf -pal`). Nog te doen: Emil moet
     de 3 bestaande, letterlijke stale bestanden handmatig verwijderen (ze
     staan buiten de gekoppelde map, dus de assistent kan er niet bij) en
     `run-demo-loop.sh --once` opnieuw draaien.

  46. **`run-demo-loop.sh --once` volledig geslaagd: alle 3 demo-apps, alle
     3 dataklassen, tegen de nieuwe services (Emil, 02/10/2026).** Na het
     opruimen van de 3 stale bestanden en de mktemp-fix uit punt 45:
     `stm-public: 1 ok, 0 mislukt`, `python-eu-nonpersonal: 1 ok, 0
     mislukt`, `sdkperf-pii: 1 ok, 0 mislukt`. Hiermee is fase 5
     (demo-apps valideren) opnieuw volledig bevestigd tegen de in punt 42
     aangemaakte services, met alle 3 tools in één doorlopende cyclus via
     het stand/booth-script -- niet alleen los per app zoals in punt 44.
     Samen met punt 44 (stm-public los, direct na de nieuwe services) is
     de volledige testketen nu twee keer onafhankelijk bevestigd. Blijft
     staan voor vlak vóór DADD zelf: de volledige testronde nog een keer
     herhalen (TODO.md, "Moet vóór DADD") en de negative-ACL-test
     (testplan-punt 5, nog niet gedaan).

  47. **TODO.md-herprioritering en nieuw `docs/demo-notes.md` (Emil,
     02/10/2026).** Op basis van de Sunburst Topic Explorer-screenshot
     (brede spreiding in markten/types, postcodegebieden en klant-ID's,
     lokale broker) bevestigt Emil dat "variatie-uitbreidingen op een
     echte broker bevestigen" afgevinkt kan worden. De negative-ACL-test
     (testplan-punt 5) verplaatst van "Zou goed zijn vóór DADD" naar "Kan
     na DADD" -- geen blocker. Koude-starttijd meten (testplan-punt 7)
     helemaal van de lijst af: Emil start op de dag zelf met een al
     "warme" omgeving (cloud-brokers al deployed/running), dus niet
     relevant. De twee presentatiepunten (Azure = Amerikaanse hyperscaler
     ondanks EU-locatie; cloud-brokers bewust in public clusters) zijn
     overgezet naar een nieuw bestand `docs/demo-notes.md` (spreektekst-
     klaar, geen code-werk) in plaats van een TODO-bullet. De
     fallback-video blijft gepland vóór DADD, maar komt pas later (geen
     wijziging in prioriteit, alleen in timing t.o.v. vandaag). Vervolg:
     de volledige testronde (fase 5, sectie 12 punten 1-4 en 6 -- NIET 5
     en 7) stap voor stap herhalen, met bevestiging na elke stap (zie
     verderop in deze sectie voor de losse punten).

  48. **Volledige testronde (fase 5, sectie 12 punten 1-4 en 6) stap voor
     stap herhaald en bevestigd (Emil, 02/10/2026).** Uitgevoerd exact
     volgens punt 47's besluit: een instructie per stap, pas door na
     Emils expliciete bevestiging.
     - **Stap 1** (Broker Manager-check): alle 3 export-queues
       (`q-export-public`/`q-export-eu-ops`/`q-export-eu-pii`) bestaan,
       leeg, geen opgehoopte berichten; alle 3 RDP's
       (`rdp-aws`/`rdp-azure`/`rdp-stackit`) staan op "Up", 0% blocked,
       0 discards op de REST-clients. ✅
     - **Stap 2** (`stm-public/publish-public.sh` -> AWS): bericht komt
       aan op AWS "Try Me!" (`classification: "public"`, topic
       `enewable/public/market/price/...`), niets op Azure/STACKIT. ✅
     - **Stap 3** (`python-eu-nonpersonal/publisher.py` -> Azure):
       berichten komen aan op Azure "Try Me!" (`classification:
       "non-personal-eu"`, topic `enewable/eu/ops/grid/load/...`), niets
       op AWS/STACKIT. ✅
     - **Stap 4** (`sdkperf-pii/publish-pii.sh` -> STACKIT): berichten
       komen aan op STACKIT "Try Me!" (`classification: "PII"`, topic
       `enewable/eu/pii/meter/reading/...`), niets op AWS/Azure. ✅ --
       opvallend: de eerste berichten deden er ruim een minuut over om
       aan te komen, terwijl de lokale queue de hele tijd leeg bleef
       (dus geen lokale stuwing). Diagnose: past bij een eenmalige
       "cold start" van de REST-verbinding naar de zojuist (via
       Terraform) aangemaakte STACKIT-service -- de eerste POST-poging
       kan stuiten op nog niet volledig gepropageerde DNS of een nog
       opstartende remote REST-ingress, waarna de RDP-restConsumer se
       ingebouwde exponential-backoff-retry het na een paar pogingen
       alsnog laat slagen; eenmaal verbonden werden de daaropvolgende
       berichten weer met normale, seconden-tussenpozen afgeleverd. Geen
       configuratiefout (stap 1 toonde al 0% blocked/discards) en geen
       blocker -- louter een observatie, in lijn met waarom
       koude-starttijd meten (testplan-punt 7) toch al bewust van de
       lijst is gehaald (punt 47).
     - **Stap 5** (negative-ACL-test, testplan-punt 5): bewust
       overgeslagen, conform punt 47 ("Kan na DADD").
     - **Stap 6** (herstart + idempotentie): lokale broker-container
       regulier herstart (`docker restart`) -- VPN `enewable`, queues en
       RDP's blijven daarbij (terecht) bestaan; dat is precies het
       scenario dat dit testplan-punt wil dekken ("opnieuw idempotent te
       draaien zonder handmatige opschoning"), niet een
       from-scratch-bootstraptest. Daarna `configure-local-broker.sh` en
       `configure-rdp-export.sh` beide opnieuw gedraaid: foutloos, elk
       sub-object meldt "(already exists, skipping)", geen duplicaten,
       inclusief de restConsumer-PATCH uit punt 43 (ook na een
       container-restart, niet alleen na een service-vervanging). ✅

     **Hiermee is de volledige testronde van sectie 12 (punten 1-4 en 6)
     opnieuw, stap voor stap, end-to-end bevestigd tegen de in punt 42
     aangemaakte services.** `TODO.md`'s bullet "Volledige testronde
     (fase 5) herhalen, stap voor stap" kan hiermee worden afgevinkt.
     Volgende taak (per Emils instructie): een visueel aantrekkelijke
     presentatie in Solace-huisstijl die het hele proces van scratch tot
     draaiende omgeving beeldend beschrijft, met architectuurdiagrammen
     en workflow-voorbeelden.

  49. **Presentatie in Solace-huisstijl gebouwd: `docs/DADD2026-Enewable-
     Soevereine-Cloud.pptx` (assistent + Emil, 02/10/2026).** Na succesvolle
     afronding van punt 48 (volledige testronde), op Emils expliciete
     instructie: een 14-dia PowerPoint-presentatie die het hele proces van
     scratch tot draaiende omgeving beeldend beschrijft, met
     architectuurdiagrammen en workflow-voorbeelden, in Solace 2025
     huisstijl (`anthropic-skills:solace-branding`-skill: kleurenpalet
     Classic Green/Deep Blue/Orange, Calibri als veilige fallback voor
     New Spirit/Figtree). Gebouwd met `pptxgenjs` als structured deck
     (eigen thema + 3 slide-layouts: Cover/Dark/Light), native
     vector-architectuurdiagram (lokale broker -> 3 gekleurde pijlen ->
     AWS/Azure/STACKIT, overeenkomstig `docs/topologie.md`), een 5-staps
     bouwproces-workflow (Terraform -> lokale broker -> ACL's -> queues/RDP
     -> demo-apps), en 3 "live bewijs"-dia's gebouwd uit de eigen, net die
     dag gemaakte Try-Me!-screenshots (bijgesneden met Pillow tot alleen de
     JSON met het `classification`-veld) plus de Sunburst-Topic-Explorer-
     opname als taxonomie-visual -- dus eigen, actuele projectdata, geen
     verzonnen voorbeelden. De twee punten uit `docs/demo-notes.md` (Azure
     = Amerikaanse hyperscaler ondanks EU-locatie; public clusters) kregen
     een eigen, uitgelichte dia. Geverifieerd: `validate.py` (schema/
     relaties/content-types) en `markitdown` (geen placeholder-tekst)
     beide zonder fouten, plus een volledige visuele QA-ronde op alle 14
     dia's via LibreOffice-rendering (2 correctieslagen: overlappende tekst
     in het architectuurdiagram en een afgekapte REST Delivery Point-pijl
     opgelost door de toelichting onder het diagram te zetten i.p.v. erop;
     de 3 bewijs-screenshots opnieuw bijgesneden zodat ze consistent direct
     bij de "Messages"-header beginnen). Geleverd via `SendUserFile` en
     gecommit in `docs/`.

  50. **Bugfix: PowerPoint-reparatiemelding bij het openen van de
     presentatie (assistent, 02/10/2026).** Emil kreeg bij het openen van
     `docs/DADD2026-Enewable-Soevereine-Cloud.pptx` in echte PowerPoint een
     "PowerPoint found a problem with content"-reparatiedialoog, terwijl
     zowel `validate.py` als de LibreOffice-rendering (punt 49) geen fout
     toonden. Root cause: een bekend `pptxgenjs`-pakketdefect, losstaand van
     deze presentatie-inhoud -- bevestigd via een losse, minimale 5-dia
     reproductie met `defineSlideMaster()`. `pptxgenjs` schrijft in
     `[Content_Types].xml` per gedefinieerd slide-layout een
     `<Override PartName="/ppt/slideMasters/slideMasterN.xml">`-regel (hier:
     N=1..14), terwijl er maar één echt `slideMaster1.xml`-bestand in het
     pakket bestaat (alle 3 layouts -- Cover/Dark/Light -- delen één
     master). Dat zijn 13 verwijzingen naar niet-bestaande onderdelen:
     ongeldig volgens de OPC-pakketspecificatie, maar iets wat noch de
     schema-validator noch LibreOffice controleert -- alleen echte
     PowerPoint doet deze consistentiecheck strikt genoeg om te weigeren.
     **Fix:** na het schrijven van het bestand de 13 overbodige
     `Override`-regels voor niet-bestaande `slideMasterN.xml`-onderdelen uit
     `[Content_Types].xml` verwijderd met een klein, op maat geschreven
     Python-script (zip openen, regex op de daadwerkelijk aanwezige
     `ppt/slideMasters/*.xml`-bestanden, regel schrijven). Opnieuw
     geverifieerd: `validate.py` ("All validations PASSED"), een volledige
     LibreOffice re-render naar PDF/JPEG en visuele inspectie van alle 14
     dia's (geen inhoudelijke wijziging t.o.v. punt 49). Herleverd via
     `SendUserFile` en opnieuw gecommit in `docs/`. Deze fix-stap
     (Content_Types opschonen na elke `pptxgenjs`-build) is het vermelden
     waard voor een volgende presentatie in deze repo of elders met
     dezelfde skill-pijplijn.

  51. **Punt 50 was niet de (enige) oorzaak -- echte root cause gevonden en
     gefixt: negatieve pijl-hoogte in het architectuurdiagram (assistent,
     02/10/2026).** Na de Content_Types-fix van punt 50 bleef het
     reparatiescherm in echte PowerPoint verschijnen; Emil klikte op
     "Cancel" (niet repareren) en zag dat dia's 4 en verder leeg bleven in
     het dia-paneel, terwijl dia's 1-3 wel toonden. Diepere XML-inspectie
     van `ppt/slides/slide4.xml` (het architectuurdiagram) toonde de echte
     fout: twee pijl-vormen (`prstGeom prst="line"`) met een **negatieve**
     `cy`-waarde in hun `<a:ext>` (bv. `cy="-1325880"`) -- de AWS- en
     Azure-pijlen, die beide van de lokale broker schuin omhoog lopen.
     OOXML staat geen negatieve shape-afmetingen toe; LibreOffice rendert
     dit toch correct (vandaar dat punt 49's visuele QA niets opmerkte),
     maar PowerPoint's eigen striktere parser accepteert dit niet en laat
     (een deel van) het bestand vallen. Root cause: de eigen `arrow()`-
     hulpfunctie in `build-deck.js` berekende `h: y2 - y1` rechtstreeks in
     plaats van `Math.abs(y2 - y1)` -- voor een naar beneden lopende pijl
     (y2 > y1) prima, maar voor een omhoog lopende pijl (y2 < y1, zoals de
     AWS/Azure-pijlen) resulteerde dit in een negatieve hoogte, ondanks dat
     `flipV` al correct op `true` stond. **Fix:** `arrow()` aangepast naar
     `w: Math.abs(x2 - x1), h: Math.abs(y2 - y1)` plus een symmetrische
     `flipH: x2 < x1` voor toekomstige naar-links lopende pijlen. Het hele
     bestand opnieuw gebouwd vanuit `build-deck.js` (inclusief de
     Content_Types-fix van punt 50, die blijft nodig), geverifieerd: geen
     negatieve `cx`/`cy`-waarden meer in enige dia-XML, `validate.py`
     ("All validations PASSED"), en een volledige visuele re-render van
     alle 14 dia's die pixel-voor-pixel identiek oogt aan punt 49/50 (de
     fix verandert alleen de interne XML-representatie, niet het
     zichtbare resultaat). Herleverd via `SendUserFile` en opnieuw gecommit
     in `docs/`. **Les:** de visuele QA-pijplijn van deze skill (LibreOffice
     + `validate.py`) kan een ongeldige-maar-renderbare XML-waarde niet
     detecteren; bij een pijl/lijn-vorm die richting kan omkeren altijd
     expliciet op negatieve `w`/`h` controleren, niet alleen op het
     eindresultaat vertrouwen.

  52. **Dia 4 (architectuurdiagram) herontworpen op Emils feedback na het
     eerste gebruik van de presentatie (assistent, 02/10/2026).** Emil gaf,
     na bevestiging dat de presentatie nu goed opent, vijf concrete
     verbeterpunten voor dia 4 en twee kleine tekstcorrecties elders:
     1) de 3 publicerende apps (`stm CLI`, `Python-script`, `SDKPerf`) van
     binnen de lokale-broker-doos naar een eigen kolom links ervan verplaatst,
     elk met een eigen doos; 2) per app expliciet de 3 topic-subtrees
     getoond waarop die publiceert (kleurgecodeerde stip + topic, dezelfde
     kleuren als de rest van de deck), in plaats van alleen de generieke
     tekst "publiceert op alle 3 subtrees"; 3) een gestileerde wereldkaart-
     achtergrond toegevoegd -- twee losse, vrij-getekende continent-
     silhouetten (Noord-Amerika en Europa, met Pillow/matplotlib + een
     spline-afvlakking gegenereerd, dus geen downloadafhankelijkheid van
     externe geodata) onder de AWS- resp. Azure/STACKIT-dozen, zodat AWS
     letterlijk boven Amerika en Azure + STACKIT boven Europa staan;
     4) de Azure-tekst "NL, maar Amerikaanse hyperscaler" veranderd naar
     "NL op Amerikaanse hyperscaler"; 5) bij elke pijl een los label met de
     exacte RDP-topic-subscriptie (`RDP: enewable/public/>` etc.) gezet, in
     plaats van één gedeeld "3 x queue + REST Delivery Point"-bijschrift.
     Daarnaast: op dia 2 "Het is een bewegingsvraagstuk" en op dia 14
     "Soevereiniteit is een classificatievraagstuk" beide veranderd naar
     "governancevraagstuk".
     **Layoutprobleem onderweg gevonden en opgelost:** de eerste versie van
     het herontwerp plaatste Azure en STACKIT naast elkaar op dezelfde
     hoogte als AWS, met als gevolg dat de (rechte) pijlen naar Azure/
     STACKIT dwars door de AWS-doos heen liepen -- zichtbaar in de
     LibreOffice-rendering, dus gevangen door de visuele QA vóór levering,
     niet door een gebruiker. Opgelost door Azure/STACKIT verticaal onder
     AWS te positioneren zodat zowel het bron- als het doelpunt van hun
     pijlen ruim boven de onderkant van de AWS-doos blijven (rechte lijnen
     kruisen een doos nooit als beide uiteinden aan dezelfde kant ervan
     liggen) -- een algemenere les voor elk vervolg-diagram met meerdere
     pijlen die een gedeeld tussenliggend vak passeren. Geverifieerd:
     `validate.py`, geen negatieve `cx`/`cy` (zie punt 51), en een volledige
     visuele re-render van alle 14 dia's (dia 2, 4 en 14 individueel
     gecontroleerd op de gevraagde wijzigingen, de overige 11 op afwezigheid
     van regressie). Herleverd via `SendUserFile` en gecommit in `docs/`.

  53. **README.md geactualiseerd en in lijn gebracht met de inmiddels
     verouderde cloud-provisioningstekst elders (Emil + assistent,
     02/10/2026).** Emil wees erop dat README.md's "Aan de cloud-kant"-
     sectie niet meer actueel was: die ging nog uit van handmatige
     provisioning en een mogelijke GCP-interim-stand-in voor STACKIT,
     terwijl er inmiddels (punt 42) een werkende Terraform-opzet
     (`cloud-setup/terraform/`) bestaat en STACKIT een eigen, echte
     `SolaceDedicated`-datacenter blijkt te hebben. Aangepast:
     1) README-titel naar "DADD 2026 - Solace / STACKIT soevereine cloud
     demo Enewable Energy"; 2) de cloud-kant-sectie herschreven: noemt nu
     Terraform als de aanbevolen, herhaalbare route (console/
     `create-service.sh` als fallback), STACKIT expliciet als GA/eigen
     datacenter, en de GCP-interim-map als niet meer gebruikt/historisch;
     3) "7. Doorlopend draaien (optioneel, bijv. voor een stand/booth)"
     ingekort naar "Doorlopend draaien"; 4) "8. Verkeer visualiseren met
     Sunburst Topic Explorer (optioneel)" naar "Optioneel: verkeer
     visualiseren met Sunburst Topic Explorer"; 5) de nummering (1 t/m 8)
     uit alle kopjes van "Stap voor stap: van nul naar draaiende demo"
     gehaald, met de bijbehorende inline `(stap N)`-verwijzingen elders in
     het bestand omgezet naar verwijzingen op sectienaam zodat ze blijven
     kloppen zonder nummers. Op Emils bredere instructie om documentatie
     consistent te houden ook **direct de twee andere plekken met
     dezelfde stale STACKIT/GCP-interim-tekst meegenomen**, zodat README.md
     niet een eenzame uitzondering wordt: `docs/cloud-brokers.md` (de hele
     sectie "STACKIT: uitgangspunt en interim-opzet" herschreven naar
     "STACKIT: inmiddels een echte, eigen datacenter") en
     `cloud-setup/README.md` (de providertabel en de inleidende alinea,
     die nog "verwacht GA komende week" zeiden terwijl de status-callout
     verderop in hetzelfde bestand al de juiste informatie gaf).
     Geverifieerd met een volledige `git diff` van alle drie bestanden
     vóór commit.
  54. **Documentatie opgeschoond: geen historische/verouderde informatie
     meer in README.md/docs/*.md/cloud-setup/* (Emil + assistent,
     02/10/2026).** Emil corrigeerde de stijl van punt 53: levende
     documentatie mag GEEN geschiedenis bevatten ("was eerder", "niet meer
     nodig", "historische referentie", gedateerde "Status (datum):"-
     meldingen) -- dat hoort uitsluitend in git-commitberichten en in dit
     logboek (sectie 13), niet in README.md/docs/*.md/cloud-setup/*.
     Alle documentatie (behalve `PLAN.md`/`TODO.md`) doorgelopen op dit
     patroon, met focus op resterende GCP-interim-verwijzingen en andere
     niet meer actuele informatie over de huidige werking/codebase:
     1) `README.md` -- GCP-interim-zin en "is inmiddels" uit de
     cloud-kant-sectie; 2) `docs/cloud-brokers.md` -- de gedateerde
     "Status (02/10/2026)"-melding en de hele GCP-interim-alinea uit de
     STACKIT-sectie verwijderd, en de sectie "Wat de AWS-, Azure- en
     GCP-interim-opzet ons hebben geleerd (fase 3 compleet)" plus de
     bijbehorende per-service-tabel (beide met verouderde
     Enterprise-250-HA-gegevens en -service-ID's van vóór de
     Terraform-herinrichting, punt 42) vervangen door een kortere,
     ongedateerde sectie met alleen generiek bruikbare lessen voor
     handmatige aanmaak via de console, met een verwijzing naar
     `local-broker/.env`/Terraform-output voor de actuele waarden i.p.v.
     vastgelegde (en dus verouderbare) service-ID's/hostnames;
     3) `cloud-setup/README.md` -- de GCP-interim-rij uit de tabel en de
     gedateerde "Status (02/10/2026)"-blockquote vervangen door een platte
     beschrijving van de huidige Terraform/Developer-100-opzet;
     4) `cloud-setup/terraform/README.md` -- "zijn verwijderd en moeten
     opnieuw aangemaakt worden" en de vraag "STACKIT: echt of nog
     interim?" (inmiddels beantwoord) vervangen door platte huidige
     feiten; 5) `cloud-setup/gcp-europe-west1-interim/README.md` volledig
     ingekort tot een korte, platte constatering dat deze map geen deel
     uitmaakt van de huidige topologie, met een verwijzing naar
     `stackit-eu01/README.md`; 6) `cloud-setup/stackit-eu01/README.md`
     herschreven van "wordt naar verwachting GA" (toekomstige
     verwachting) naar de huidige, al bereikte situatie (eigen
     `SolaceDedicated`-datacenter), "interim mimic op GCP"-sectie
     verwijderd; 7) `cloud-setup/aws-us-east/README.md` en
     `azure-west-europe/README.md` -- de doorgestreepte
     voortgangs-checklists en de verouderde Enterprise-250-HA/
     28-09-2026-servicegegevens (vóór de Terraform-herinrichting van punt
     42) vervangen door een beknopte, actuele beschrijving (Developer
     100-tier, Terraform als aanbevolen route); 8) `docs/topologie.md` --
     de sectie "Interim: STACKIT-knooppunt tijdelijk gemimickt op GCP
     België" verwijderd en de broker-tabel ontdaan van een ongeverifieerde
     "HA"-claim op de Developer-100-tier; 9) `docs/lokale-broker.md` --
     de resterende "STACKIT/GCP-interim"-vermeldingen vervangen door
     "STACKIT", de ongeverifieerde HA-claim gecorrigeerd, en twee
     meta-opmerkingen die zichzelf als "achterhaald" beschreven
     verwijderd in plaats van gecorrigeerd laten staan. Buiten scope
     gehouden: de uitgebreide testronde-log in `docs/lokale-broker.md`
     zelf (chronologische verificatiestappen met datums) is een
     verificatierapport, geen "huidige stand van zaken"-beschrijving, en
     dus niet hetzelfde probleem als de overige documentatie. Nieuwe
     conventie vastgelegd in `SKILLS.md`, "Documentatie bevat alleen de
     huidige stand van zaken, geen geschiedenis", om deze fout niet
     opnieuw te maken. Geverifieerd met `git diff --stat` over alle
     gewijzigde bestanden en de soft-hyphen-sweep vóór commit.

  55. **Documentatiestijl verder aangescherpt: README-sectieheader en
     "--" naar "-" in alle documentatie (Emil + assistent, 02/10/2026).**
     Emil formuleerde de achterliggende regel expliciet: een repository is
     iets levends met een tijdloze, actuele status -- Git (commits, tags)
     is het mechanisme om bij een eerdere versie uit te komen, dus
     documentatie is geen tijdregistratie. Deze repo kent nog geen
     releases; mocht dat ooit komen, dan is een apart release-bestand
     (release notes/changelog) de juiste plek voor tijdgebonden info, niet
     README.md/docs/*.md. Vastgelegd in `SKILLS.md`, "Documentatie bevat
     alleen de huidige stand van zaken, geen geschiedenis" (uitgebreid met
     deze framing). Concreet toegepast: 1) README.md's sectieheader "Aan
     de cloud-kant -- dit README automatiseert dit NIET:" (nog een relict
     van vóór punt 54) vervangen door "Aan de cloud-kant:", en de sectie
     zelf herschreven om te LEIDEN met de huidige situatie (de 3 services
     worden aangemaakt met Terraform) in plaats van met wat het README
     niet doet, met behoud van de lijst met per-service benodigde
     gegevens; 2) alle dubbele koppeltekens ("--") die als gedachtestreepje
     in doorlopende tekst werden gebruikt, in README.md en alle overige
     documentatie (behalve `PLAN.md`/`TODO.md`, die hun eigen, bestaande
     stijl behouden) vervangen door een enkel koppelteken ("-") -- via een
     script dat eerst fenced codeblokken (bash-voorbeelden, Mermaid-
     diagrammen, ASCII-art) buiten schot houdt, zodat CLI-vlaggen als
     `--class`/`--delivery-mode` en Mermaid-pijlsyntax (`-->`) onveranderd
     bleven; nieuwe stijlregel toegevoegd aan `SKILLS.md`. Geverifieerd:
     een grep op whitespace-omsloten "--" buiten codeblokken geeft nul
     treffers meer in de doorgelopen documentatie, en de bestaande
     CLI-vlaggen/ASCII-art/Mermaid-syntax zijn steekproefsgewijs
     gecontroleerd als ongewijzigd.

  56. **Nieuw script: Broker Manager-admin-credentials via de Mission
     Control API ophalen (Emil + assistent, 02/10/2026).**
     `cloud-setup/solace-cloud-api/get-broker-manager-credentials.sh`
     toegevoegd: haalt per cloud-broker (AWS, Azure, STACKIT) de
     SEMP-admin (manager-rol) username/password op via
     `GET .../missionControl/eventBrokerServices/{id}` en schrijft
     `{aws,azure,stackit}.{adminUsername,adminPassword}` naar
     `output/broker-admin-credentials.json` (gitignored), plus het
     volledige rauwe antwoord per service naar
     `output/broker-manager-credentials-raw/` voor verificatie. Twee
     dingen konden niet live getest worden (netwerktoegang naar
     api.solace.cloud/het STACKIT-orgdomein is geblokkeerd vanuit deze
     sessie): 1) het pad
     `data.messageVpn.managerManagementCredential.{username,password}` is
     afgeleid van het schema van de `solacecloud`-Terraform-provider
     (bevestigd via de providerdocumentatie en via de structuur van de
     al aanwezige `output/service-{aws,azure,stackit}.json`-bestanden in
     deze repo, beide met velden `message_vpn.manager_management_credential.
     {username,password}`), niet rechtstreeks tegen een live GET-respons;
     2) of de respons deze credentials toont hangt af van een
     tokenscope ("Get My Services with Management Credentials" of
     org-breed "Get Services with Management Credentials", gevonden in
     de Solace-documentatie over API-tokens) die het bestaande
     `SOLACE_CLOUD_API_TOKEN` mogelijk niet heeft. Het script schrijft
     daarom altijd ook de rauwe respons weg zodat dit verifieerbaar/
     corrigeerbaar is. Nieuwe env-variabelen toegevoegd aan
     `cloud-setup/solace-cloud-api/.env.example`:
     `AWS_AZURE_ORG_API_TOKEN`/`_API_BASE`, `STACKIT_ORG_API_TOKEN`/
     `_API_BASE` (STACKIT zit in een andere Solace Cloud-organisatie met
     een eigen API-domein, zie punt 42) en `{AWS,AZURE,STACKIT}_SERVICE_ID`.
     `cloud-setup/README.md` stap 4 uitgebreid met een verwijzing naar dit
     script als alternatief voor het handmatig overtypen van de
     SEMP-admin-credentials vanaf de Connect-tab.

  57. **Bugfix punt 56: Mission Control API geeft geen management-
     credentials terug, script omgezet naar Terraform-state (Emil +
     assistent, 02/10/2026).** Emil draaide
     `get-broker-manager-credentials.sh` (punt 56) na het invullen van
     echte org-tokens: alle drie `adminUsername`/`adminPassword` kwamen
     `null` terug. De rauwe STACKIT-respons die Emil terugplakte bevatte
     geen `messageVpn`-object, alleen basisvelden (id/name/datacenterId/
     serviceClassId/...). Opgezocht tegen de publieke OpenAPI-spec van de
     Mission Control API
     (`https://api.solace.dev/cloud/openapi/mission-control.json`): de
     substring "ManagementCredential" komt daar nergens in voor -- dit is
     dus geen ontbrekende tokenscope, de publiek gedocumenteerde GET
     bevat dit veld simpelweg niet. Omdat deze credentials al wel
     aanwezig bleken in deze repo's eigen
     `output/service-{aws,azure,stackit}.json` (gevuld via
     `terraform output -json` ten tijde van het aanmaken van de services,
     punt 42), is het script herschreven om `terraform output -json
     {aws,azure,stackit}_service` als bron te gebruiken in plaats van een
     curl naar de Mission Control API. De AWS_AZURE_ORG_*/STACKIT_ORG_*-
     env-variabelen en de aanname rond `expand=`-parameters uit punt 56
     zijn daarmee overbodig en weer uit `.env.example` verwijderd.
     Vastgelegd in `SKILLS.md`, "Mission Control API geeft geen
     broker-management-credentials terug via GET", zodat dit niet opnieuw
     wordt uitgezocht. Zijlijn: de twee per-org API-tokens die Emil per
     ongeluk in het script zelf plakte (i.p.v. in `.env`) stonden alleen
     in de ongecommitte werkmap, nooit in git-historie; direct hersteld
     naar de placeholder-versie en de echte waarden alsnog in het
     (gitignored) `.env`-bestand gezet.

  58. **STACKIT-service extern verwijderd, opnieuw aangemaakt via
     Terraform, met correctie van het datacenter (Emil + assistent,
     07/10/2026).** De STACKIT event-broker-service was buiten Terraform om
     verwijderd (AWS en Azure ongemoeid); `terraform plan` bevestigde dit
     meteen: nul drift op AWS/Azure, een schone `+ create` voor
     `stackit_eu01` op het oude, in `terraform.tfvars` vastgelegde
     datacenter (`stackitdemo-stackit-eu01-production`). De eerste
     `terraform apply` slaagde functioneel, maar de nieuwe service
     verscheen in de Solace Cloud console onder het generieke "Private
     Cloud"-icoon i.p.v. het STACKIT-icoon. Uitgezocht via het al aanwezige
     `output/datacenters-stackit.json` (geen nieuwe live call nodig):
     `stackitdemo-stackit-eu01-production` heeft `datacenterType:
     SolaceDedicated` (provider `k8s`) -- een aan deze ene organisatie
     gebonden, dedicated cluster -- terwijl diezelfde lijst ook een echte
     publieke regio bevat, `ske-eu01` (`datacenterType: SolacePublic`,
     provider `ske` = "StackIT Kubernetes Engine", regio "Germany"). Dat
     laatste is de juiste keuze. `variables.tf` en `terraform.tfvars`
     aangepast naar `datacenter_id_stackit = "ske-eu01"`; `terraform plan`
     gaf vervolgens `Error: Immutable Attribute Change` op `datacenter_id`
     (bekende ruwe rand van deze beta-provider: zou een replace-plan moeten
     voorstellen maar faalt hard tijdens plan-evaluatie). Opgelost met
     `terraform state rm solacecloud_service.stackit_eu01` (stopt alleen
     het volgen door Terraform, raakt de echte cloud-resource niet aan),
     waarna een schone `+ create` op `ske-eu01` plan-baar was. De eerste
     `apply` had de service al aangemaakt onder de naam
     `ez-dadd-2026-stackit-eu01`, dus de nieuwe create botste op "name must
     be unique"; de nieuwe service is daarom hernoemd naar
     `ez-dadd-2026-ske-eu01` in `main.tf` (Terraform-resource-adres
     `stackit_eu01` ongewijzigd gelaten) en succesvol aangemaakt. Daarna:
     `local-broker/.env` bijgewerkt met de nieuwe SMF-/REST-hostnamen,
     VPN-naam en SEMP-admin-credentials uit `terraform.tfstate` (de
     `terraform` CLI is niet beschikbaar in de sandbox, dus rechtstreeks
     als JSON gelezen i.p.v. via `terraform output`), een nieuw
     bridge-wachtwoord gegenereerd en via
     `configure-remote-bridge-users.sh` gepusht (AWS/Azure gaven daarbij
     een cosmetische `WARN` i.p.v. de vriendelijke "already
     exists"-melding, omdat SEMP hier `code: 10`/`ALREADY_EXISTS`
     teruggeeft en het script specifiek op `code: 6001` matcht -- geen
     functionele wijziging op AWS/Azure, puur een loggingmismatch), en
     `configure-rdp-export.sh` opnieuw gedraaid zodat `rdp-stackit` weer
     naar de nieuwe host wijst. Eind-tot-eind bevestigd: `rdp-stackit`
     staat op "Up" in Broker Manager en live PII-berichten komen aan in de
     STACKIT "Try Me!"-tab op `enewable/eu/pii/>`. De oude, verweesde
     service `ez-dadd-2026-stackit-eu01` (op
     `stackitdemo-stackit-eu01-production`, niet meer door Terraform
     gevolgd na de `state rm`) draait nog en moet handmatig via de console
     verwijderd worden. `docs/cloud-brokers.md`, `cloud-setup/README.md` en
     `cloud-setup/stackit-eu01/README.md` gecorrigeerd: de eerdere aanname
     dat `stackitdemo-stackit-eu01-production` "STACKIT's eigen, echte
     datacenter" was, was onjuist -- dat is de
     SolaceDedicated/Private-Cloud-cluster, niet de publieke regio -- en
     bijgewerkt naar de nieuwe servicenaam.
     `docs/Plan-van-aanpak-DADD2026-Enewable.docx` bevat geen van de
     specifieke termen die hier wijzigen (alleen een generieke
     "datacenter"-vermelding) en is daarom niet opnieuw gegenereerd voor
     deze fix.

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

**Zie ook [`TODO.md`](TODO.md)** in de repo-root voor de actuele,
geprioriteerde actielijst (sectie 13, punt 39) -- dit is de historische
lijst per stap; nieuwe/openstaande acties worden vanaf nu primair in
`TODO.md` bijgehouden.

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
6. ~~Documentatie synchroniseren met de code, README herschrijven als
   stap-voor-stap-handleiding, en een doorlopend-draaien-script
   toevoegen voor stand/booth-gebruik.~~ ✅ Zie sectie 13, punt 31:
   3 documenten gecorrigeerd (stale RDP/bridge-verwijzingen), `README.md`
   is nu de volledige from-scratch-handleiding, en
   `local-broker/scripts/run-demo-loop.sh` roept de 3 demo-apps herhaald
   aan (default: elke 30s een cyclus, of `--interval 0` voor direct
   achter elkaar).
8. ~~Elke demo-app alle 3 dataklassen laten publiceren (i.p.v. maar één per
   app), zodat de topic -- niet de tool -- overtuigend de bestemming
   bepaalt.~~ ✅ Zie sectie 13, punt 32: alle 3 scripts herschreven met
   per-klasse credential/topic/payload en per-klasse foutisolatie, `--class`
   -vlag toegevoegd, gedeelde `demo-apps/sample-payloads/` geïntroduceerd,
   alle betrokken documentatie (READMEs, `docs/demo-apps.md`,
   `docs/topologie.md` + `topology/topologie.mmd`, root-`README.md`)
   bijgewerkt.
9. Draaiboek en fallback-opname voorbereiden (sectie 11, fase 6).
