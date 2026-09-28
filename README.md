# DADD 2026 -- Solace / STACKIT: soevereine cloud-demo (Enewable)

Demo-project bij de presentatie **"Ontwerpen voor soevereiniteit: de
verborgen kosten van het verlaten van de hyperscalers"** van Emil Zegers,
DADD 2026.

Vier Solace-brokers (1 lokaal, self-managed + 3 Solace Cloud HA-services in
AWS/Azure/STACKIT), verbonden via REST Delivery Points (RDP's), die laten
zien hoe data op basis van classificatie (publiek / niet-persoonlijk EU /
gevoelige PII) automatisch naar precies de juiste, en alleen de juiste,
bestemming stroomt. Drie losse publicatie-tools (stm, een Python-script,
SDKPerf) publiceren allemaal naar dezelfde lokale broker, en publiceren
daarbij elk **alle drie de dataklassen** -- welke tool je gebruikt maakt
voor de bestemming geen enkel verschil, alleen de topic (en de
bijbehorende, per-klasse gescoped identiteit) bepaalt volledig (en
uitsluitend) op welke cloud-broker een bericht landt.

**Voor de volledige achtergrond, afwegingen en de complete geschiedenis van
dit project: [`PLAN.md`](PLAN.md).** Dit README is de praktische
stap-voor-stap-handleiding om de demo vanaf nul te draaien; `PLAN.md` en de
map [`docs/`](docs/) leggen uit *waarom* het zo is opgezet en welke
alternatieven zijn onderzocht en verlaten (o.a. Message VPN Bridges, zie
`docs/lokale-broker.md`).

## Architectuur in één oogopslag

```
stm           --\                                                /--> AWS       (enewable/public/>)
python-script  ---> lokale broker (enewable-VPN) -- RDP's per klasse ---> Azure     (enewable/eu/ops/>)
sdkperf        --/     (elke tool publiceert alle 3 klassen)      \--> STACKIT   (enewable/eu/pii/>)
```

Elke demo-app publiceert **DIRECT** naar de lokale broker, op **alle drie**
topic-subtrees, elk met zijn eigen ACL-gescoped client-username
(`pub-public`/`pub-eu-ops`/`pub-eu-pii`) die (via een ACL-profiel) alleen op
die ene subtree mag publiceren -- welke tool de afzender is, doet voor de
bestemming niet ter zake. Op de lokale broker vangt een **queue per
subtree** dat bericht automatisch op ("message promotion"), en een **REST
Delivery Point (RDP)** stuurt die queue één-op-één door naar het
REST-endpoint van de bijbehorende cloud-broker, op exact dezelfde topic.
Zie [`docs/topologie.md`](docs/topologie.md) voor het volledige diagram en
[`docs/lokale-broker.md`](docs/lokale-broker.md) voor de RDP-mechanica in
detail.

## Vereisten

**Op je eigen machine (macOS/Linux):**

- Docker Desktop, met minimaal 4-8 GB RAM en ~6 GB vrije schijfruimte
  toegewezen.
- `curl` en `python3` (meestal al aanwezig).
- Node.js + npm (voor de Solace Try-Me CLI, `stm`).
- Java (voor SDKPerf) -- zie
  [`demo-apps/sdkperf-pii/README.md`](demo-apps/sdkperf-pii/README.md) voor
  de downloadlink.
- `jq` is optioneel maar aanbevolen (leesbaardere scriptoutput); alles werkt
  ook zonder.

**Aan de cloud-kant -- dit README automatiseert dit NIET:**

Dit README gaat ervan uit dat de 3 Solace Cloud broker-services (AWS,
Azure, STACKIT -- of, zolang STACKIT nog niet algemeen beschikbaar is, de
tijdelijke GCP-interim-stand-in, zie
[`cloud-setup/gcp-europe-west1-interim/README.md`](cloud-setup/gcp-europe-west1-interim/README.md))
**al bestaan**, en dat je de volgende gegevens per service bij de hand hebt
(te vinden op de Connect-tab van elke service in de Solace Cloud console):

- SMF-hostname (bijv. `mr-connection-xxxxxxxxxxx.messaging.solace.cloud`,
  poort 55443/TLS).
- REST-hostname:poort (meestal dezelfde hostname als SMF, poort 9443/TLS --
  bevestig dit op de Connect-tab, en zet REST-messaging aan voor die
  service als het nog uit staat).
- Message VPN-naam.
- Een publish-only client-username + wachtwoord, met een ACL-profiel dat
  alleen publiceren toestaat op de juiste topic-subtree voor die broker
  (`enewable/public/>` voor AWS, `enewable/eu/ops/>` voor Azure,
  `enewable/eu/pii/>` voor STACKIT).

Als je deze services of credentials nog niet hebt: zie
[`cloud-setup/README.md`](cloud-setup/README.md) en de submap per provider
voor hoe je ze zelf aanmaakt (via de Solace Cloud console, of via
`cloud-setup/solace-cloud-api/create-service.sh` +
`configure-remote-bridge-users.sh`) -- dat valt buiten de scope van dit
README.

## Stap voor stap: van nul naar draaiende demo

### 1. Lokale broker starten

```bash
cd local-broker
cp .env.example .env
```

Vul `.env` volledig in: de `AWS_*`/`AZURE_*`/`STACKIT_*`-velden met de
gegevens uit de vorige sectie, en laat de `PUB_*`- en `LOCAL_*`-velden op
hun default staan (die worden zo aangemaakt door de scripts hieronder).

```bash
./docker-run.sh
```

Start de lokale, self-managed Solace PubSub+ broker in Docker en wacht tot
de SEMP-management-API bereikbaar is. Bevestig daarna in Broker Manager
(`http://localhost:8080`, admin/admin) dat de broker draait.

### 2. Lokale broker configureren (Message VPN, ACL's, publishers)

```bash
./semp/configure-local-broker.sh
```

Maakt de Message VPN `enewable` aan, plus de 3 scoped publisher
client-usernames (`pub-public`/`pub-eu-ops`/`pub-eu-pii`) die elk alleen op
hun eigen topic-subtree mogen publiceren, en een read-only `monitor`
client-username die op heel `enewable/>` mag *subscriben* maar nergens op
mag publiceren (bedoeld voor visualisatietools, zie "Verkeer visualiseren"
hieronder). Idempotent -- veilig om opnieuw te draaien (bijv. na een
container-restart, zie "Geen persistente opslag" in `docs/lokale-broker.md`).

### 3. RDP-export naar de 3 cloud-brokers configureren

```bash
./semp/configure-rdp-export.sh
```

Maakt per topic-subtree een durable queue + een REST Delivery Point dat die
queue naar de bijbehorende cloud-broker exporteert (zie "Architectuur"
hierboven). Vereist dat de `*_REMOTE_REST_HOST`/`*_REMOTE_REST_PORT`-velden
in `.env` correct zijn (stap 1).

### 4. Verifiëren in Broker Manager

Open `http://localhost:8080` > VPN `enewable` en controleer:

- **Queues**: `q-export-public` / `q-export-eu-ops` / `q-export-eu-pii`
  bestaan, met de juiste topic-subscription en (zodra er een bericht
  doorheen is geweest) "Bind Count" 1 (de RDP zelf).
- **REST Delivery Points**: `rdp-aws` / `rdp-azure` / `rdp-stackit` staan op
  "Up".

Als een RDP "Down" blijft of de queue-binding een fout geeft, geeft Broker
Manager zelf geen reden -- draai `./semp/diagnose-rdp.sh` (schrijft naar
`../output/diagnose-rdp.txt`) voor de SEMP v2 MONITOR-details, en zie
"Bekende risico's" in `docs/lokale-broker.md` voor de meest voorkomende
oorzaken die deze demo eerder heeft blootgelegd.

### 5. De 3 demo-apps installeren (eenmalig)

Elke demo-app publiceert naar de lokale broker met de 3 al aangemaakte,
per-klasse gescoped client-usernames (stap 2) -- er is geen extra
configuratie per app nodig, alleen de tool zelf installeren. Elke tool
publiceert standaard alle 3 dataklassen (publiek -> AWS, niet-persoonlijk
EU -> Azure, PII -> STACKIT); zie
[`demo-apps/README.md`](demo-apps/README.md) voor de `--class`-optie om een
tool tot één klasse te beperken.

**stm:**

```bash
npm install -g solace-tryme-cli
stm --version
```

**Python-script:**

```bash
cd demo-apps/python-eu-nonpersonal
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cd ../..
```

**SDKPerf:**

Download SDKPerf voor je platform via
[Solace Developer Tools](https://www.solace.dev/) (of de "Try Me!"-download
in de Solace Cloud console) en pak het uit. Als `sdkperf_java.sh` niet op je
PATH staat, zet het volledige pad naar het binary in `local-broker/.env`:

```bash
# local-broker/.env
SDKPERF_BIN=/pad/naar/sdkperf-jcsmp-x.y.z/sdkperf_java.sh
```

`demo-apps/sdkperf-pii/publish-pii.sh` leest dit automatisch (samen met de
rest van `.env`) -- je hoeft `.env` zelf nergens handmatig te `source`'n.

### 6. Eén demo-app draaien en op alle 3 brokers verifiëren

Open in de Solace Cloud console de "Try Me!"-tab van elke van de 3
cloud-services (AWS/Azure/STACKIT), en laat ze het liefst naast elkaar open
staan. Draai dan **één** van de drie tools -- bijvoorbeeld:

```bash
./demo-apps/stm-public/publish-public.sh
```

Dit ene commando publiceert alle 3 dataklassen (elk met zijn eigen
gescoped credential). Verifieer dat de berichten op alle 3 de brokers
aankomen, elk op de juiste topic en nergens anders:

- **AWS**: `enewable/public/>`
- **Azure**: `enewable/eu/ops/>`
- **STACKIT** (of de GCP-interim-stand-in): `enewable/eu/pii/>`

Herhaal dit gerust met de andere twee tools (Python-script, SDKPerf) om te
laten zien dat het geen toevalstreffer van één specifieke tool is -- alle
drie doen precies hetzelfde:

```bash
cd demo-apps/python-eu-nonpersonal && source .venv/bin/activate
python publisher.py
cd ../..
```

```bash
./demo-apps/sdkperf-pii/publish-pii.sh
```

Gebruik `--class public|eu-ops|eu-pii` op elke tool om tot één dataklasse
te beperken (handig om, bijvoorbeeld, alleen de PII-stroom naar STACKIT
te laten zien). Zie [`demo-apps/README.md`](demo-apps/README.md) voor alle
opties.

Als alle drie de brokers berichten ontvangen op precies hun eigen topic,
werkt de volledige governed-routing-keten end-to-end. Zie
[`docs/demo-apps.md`](docs/demo-apps.md) voor het voorgestelde draaiboek
voor de live presentatie zelf.

### 7. Doorlopend draaien (optioneel, bijv. voor een stand/booth)

Voor een situatie waarin de 3 "Try Me!"-tabs continu verse data moeten
tonen zonder dat iemand steeds handmatig een script opnieuw start:

```bash
./local-broker/scripts/run-demo-loop.sh
```

Roept alle 3 de bovenstaande scripts steeds opnieuw aan (default: elke 30
seconden een nieuwe cyclus van alle 3), tot je op Ctrl-C drukt (die drukt
dan een korte samenvatting: aantal cycli en geslaagd/mislukt per app). Eén
app die faalt (bijv. SDKPerf niet gevonden) stopt de andere twee niet.

Opties (zie ook `./local-broker/scripts/run-demo-loop.sh --help`):

```bash
# Ander interval tussen cycli (default: 30s)
./local-broker/scripts/run-demo-loop.sh --interval 10

# Cycli direct achter elkaar, zonder pauze
./local-broker/scripts/run-demo-loop.sh --interval 0

# Vast aantal berichten per klasse per cyclus (i.p.v. elk script se eigen
# default: stm 10, python 20, sdkperf 20) -- te combineren met --interval
./local-broker/scripts/run-demo-loop.sh --interval 10 --count 5

# Precies één cyclus, dan stoppen (sanity-check vóór je het onbeheerd
# laat draaien op een stand)
./local-broker/scripts/run-demo-loop.sh --once --count 1
```

### 8. Verkeer visualiseren met Sunburst Topic Explorer (optioneel)

[Sunburst Topic Explorer](https://explorer.solace.dev/) laat de topic-boom
van een broker live zien terwijl er berichten doorheen stromen -- handig om
tijdens de demo te laten zien hoe `enewable/public/>`,
`enewable/eu/ops/>` en `enewable/eu/pii/>` zich als 3 losse takken
gedragen. Connect met:

- **URL**: `ws://localhost:8008` (dezelfde web-messaging-poort als `stm`)
- **Message VPN**: `enewable`
- **Username / Password**: `monitor` / de waarde van `MONITOR_PASSWORD` in
  je `local-broker/.env` (default in `.env.example`: `monitor-pw`)

Dit is *niet* dezelfde combinatie als `default`/`default` waarmee je
waarschijnlijk al tegen de broker se ingebouwde `default`-VPN hebt getest
-- die combinatie bestaat alleen op de VPN die letterlijk `default` heet.
`enewable` heeft zijn eigen client-usernames (stap 2): de 3
publish-only-accounts (`pub-*`) mogen expliciet niet subscriben, dus
hiervoor is een apart, read-only `monitor`-account aangemaakt dat wél op
heel `enewable/>` mag subscriben maar zelf niets kan publiceren.

**Let op het "Topic(s)"-veld in Sunburst zelf**: dat staat standaard op
`#noexport/>, #noexport/#P2P/>` (een intern Solace-topicprefix, niet onze
demo-data) -- verander dit naar `enewable/>` vóór je op "Start/Subscribe"
klikt, anders krijg je een "Subscription ACL Denied"-foutmelding. Dit is
geen ACL-probleem (`acl-monitor` staat al goed, zie hierboven) maar puur
de topic die Sunburst zelf standaard invult.

## Problemen oplossen

- **RDP staat op "Down" / queue-binding geeft een fout**: zie stap 4
  hierboven en `docs/lokale-broker.md`, sectie "Bekende risico's".
- **`command not found` voor `stm`/`sdkperf_java.sh`/python-modules**: zie
  stap 5 -- dit zijn eenmalige installatiestappen per demo-app, geen
  repo-bug.
- **Je gebruikt zsh (macOS-default) en een commando uit dit README lijkt
  raar te falen** (bijv. een `ModuleNotFoundError` na een geslaagd
  ogende `pip install`): controleer of je zelf een `#`-toelichting achter
  een commando hebt geplakt op dezelfde regel -- zsh negeert een inline
  `#`-commentaar, in tegenstelling tot bash, niet automatisch.
- **Overig**: `local-broker/semp/diagnose-local-auth.sh`,
  `diagnose-rdp.sh` en `watch-rdp-live.sh` zijn read-only diagnostiekscripts
  (SEMP v2 MONITOR-API) die tijdens de ontwikkeling van deze demo elk
  concreet probleem hebben blootgelegd -- zie hun eigen header-commentaar en
  `docs/lokale-broker.md` voor de volledige geschiedenis.

## Taal

Documentatie (`PLAN.md`, `docs/`, dit README) is in het Nederlands. Code en
configuratie (scripts, JSON, commentaar daarin) is in het Engels, conform
gangbare praktijk voor techniek/config.
