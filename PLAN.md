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
| Fase 4 -- Lokale broker + bridges | 🔄 Bezig | ✅ Broker, VPN, ACL's, 3 bridge-objecten gereed (bevestigd in Broker Manager: alle 3 zichtbaar, status Down). 5e bug gevonden: de remote-auth-velden (`remoteAuthenticationScheme` e.a.) horen op het bridge-object zelf, niet op `remoteMsgVpns` (SEMP-fout 11 "Unknown attribute") -- gefixt. 🔄 Emil draait het script opnieuw en verifieert dat alle 3 bridges "Up" tonen |
| Fase 5 -- Demo-apps valideren | Nog te doen | |
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
brokertabel en de topic-taxonomie. Kort samengevat: lokaal → 3 bridges →
3 cloud-brokers, 1 topic-subtree per bridge, geen overlap.

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
|       `-- configure-local-broker.sh
|-- cloud-setup/
|   |-- README.md
|   |-- aws-us-east/README.md
|   |-- azure-west-europe/README.md
|   |-- stackit-eu01/README.md
|   |-- gcp-europe-west1-interim/README.md
|   `-- solace-cloud-api/
|       |-- create-service.sh
|       |-- configure-remote-bridge-users.sh   <- creates bridge client-usernames + ACL's on the 3 cloud brokers
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
| 4 | Lokale broker + bridges | ✅ VPN + ACL's + bridge-objecten gereed (bridges zichtbaar, nog Down); `configure-local-broker.sh` 5 bugs gefixt; 🔄 opnieuw te draaien | Bezig |
| 5 | Demo-apps valideren | Alle 3 tools end-to-end testen (publiceren → juiste cloud-broker, nergens anders) | Meerdere keren voor DADD, niet pas op de dag zelf |
| 6 | Draaiboek + fallback-opname | Live-timing oefenen, schermopname als fallback maken | Week vóór DADD |
| 7 | Op de dag zelf | `docker-run.sh` + `configure-local-broker.sh` (of al draaiend laten staan), demo-apps klaarzetten | Vlak voor het slot |

## 11. Draaiboek voor de live demo

Zie [`docs/demo-apps.md`](docs/demo-apps.md), sectie "Voorgesteld draaiboek".
Kernpunt: drie Solace Cloud "Try Me!"-tabs (AWS/Azure/STACKIT) zichtbaar
naast elkaar, zodat het publiek in real-time ziet dat elke dataklasse
uitsluitend op zijn eigen broker verschijnt.

## 12. Testplan / verificatie

Vast controlelijstje, uit te voeren na elke wijziging aan bridge- of
ACL-configuratie, en sowieso nog een keer vlak voor DADD:

1. Alle 3 bridges tonen "Up" in Broker Manager van de lokale broker.
2. `stm-public/publish-public.sh` → bericht verschijnt **alleen** op AWS.
3. `python-eu-nonpersonal/publisher.py` → bericht verschijnt **alleen** op Azure.
4. `sdkperf-pii/publish-pii.sh` → bericht verschijnt **alleen** op STACKIT.
5. Herhaal 2-4 maar publiceer bewust op de "verkeerde" client-username voor
   een topic (bijv. `pub-public` proberen te laten publiceren op
   `enewable/eu/pii/...`) → dit moet door de ACL geweigerd worden (negative
   test, laat de governance-garantie zien, niet alleen de happy path).
6. Herstart de lokale broker-container en herhaal `configure-local-broker.sh`
   → opnieuw idempotent te draaien zonder handmatige opschoning.
7. Meet de tijd van "koude start" (docker run tot alle 3 bridges Up) -- moet
   ruim binnen de gewenste ~5 minuten passen; zo niet, overweeg de
   cloud-brokers al vooraf "warm" te laten draaien en alleen de lokale
   broker + bridges als het live-onderdeel te zien.

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
3. Bridge-client-username `enewable-local-bridge` aanmaken op elke
   cloud-broker (SEMP-admin-gegevens per broker in `local-broker/.env`
   invullen en `cloud-setup/solace-cloud-api/configure-remote-bridge-users.sh`
   draaien -- zelf, niet via de assistent, zie `docs/cloud-brokers.md`), en
   daarna `local-broker/semp/configure-local-broker.sh` valideren tegen een
   echte broker (SEMP API Browser) en waar nodig corrigeren.
4. Eerste end-to-end testronde volgens sectie 12.
5. Draaiboek en fallback-opname voorbereiden (sectie 11, fase 6).
