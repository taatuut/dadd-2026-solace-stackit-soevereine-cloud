# Demo-apps (databronnen)

Drie losse publicatie-tools -- allemaal publicerend naar de **lokale**
broker (nooit rechtstreeks naar een cloud-broker -- dat gaat via REST
Delivery Points, zie `../local-broker/`):

| Tool | Map |
|---|---|
| Solace Try-Me CLI (`stm`) | `stm-public/` |
| Python-script (Solace Python API) | `python-eu-nonpersonal/` |
| SDKPerf | `sdkperf-pii/` |

**Elke tool publiceert, standaard, alle drie de dataklassen in één run** --
publiek, niet-persoonlijk EU, en gevoelige PII -- niet slechts één klasse
per app. Dat is bewust: het bewijst dat de bestemming (AWS/Azure/STACKIT)
volledig wordt bepaald door de **topic** waarop gepubliceerd wordt, en niet
door welke tool je toevallig draait. Dezelfde `stm`-CLI die net een bericht
op AWS liet landen, laat het volgende bericht -- zonder enige codewijziging,
alleen een ander topic + credential -- op STACKIT landen.

| Dataklasse | Topic-subtree | RDP naar |
|---|---|---|
| Publiek (energieprijzen, weer) | `enewable/public/>` | AWS (`rdp-aws`) |
| Niet-persoonlijk, EU (netbelasting) | `enewable/eu/ops/>` | Azure (`rdp-azure`) |
| Gevoelige PII (meterstanden) | `enewable/eu/pii/>` | STACKIT (`rdp-stackit`) |

Binnen die subtree is de topic **dynamisch**: de laatste 1-2 niveaus komen
uit het bericht zelf, niet uit een vaste string. Bijvoorbeeld:
`enewable/public/market/price/intraday-price/BE` (type + market),
`enewable/eu/ops/grid/load/grid-load-aggregate/3500-NL` (type +
postcodeArea), `enewable/eu/pii/meter/reading/ENW-NL-000482`
(customerId). Dit werkt zonder enige broker-wijziging, want alle
ACL-exceptions en RDP-export-queue-subscriptions staan al op de hele
`enewable/<klasse>/>`-subtree, niet op een exacte topic -- extra niveaus
erbij komt er automatisch in mee.

Voor **eu-ops**/**eu-pii** lezen `stm`/`sdkperf` deze velden uit hun
statische JSON-bestand in `sample-payloads/` (met `jq`, of een
grep/sed-fallback als `jq` ontbreekt) -- die blijven per run vast. Voor
**publiek** variëren `type` en `market` juist WEL per bericht, willekeurig
gekozen uit 3 types (`day-ahead-price`/`intraday-price`/`imbalance-price`)
en de 5 markten (`NL`/`BE`/`LU`/`DE`/`FR`) -- alle 3 tools bouwen daarvoor
per bericht een nieuwe payload/topic op (`stm`/`sdkperf`: COUNT losse
CLI-aanroepen i.p.v. één batch, dus zichtbaar langzamer voor de
publiek-klasse; het Python-script deed dit al zo voor zijn eigen
velden). Het Python-script bouwt de topic voor alle 3 klassen per
verstuurd bericht op, omdat de veldwaarden daar per bericht rouleren.

Voor elke klasse gebruikt elke tool zijn eigen, met een ACL-profiel
beperkte client-username (`pub-public`/`pub-eu-ops`/`pub-eu-pii`,
aangemaakt door `../local-broker/semp/configure-local-broker.sh`) -- de
tool wisselt dus per klasse van identiteit, niet alleen van topic. Zo
blijft de "governed sharing"-gedachte uit de presentatie ook aan de
publicatiekant intact: zelfs als een tool geprogrammeerd zou worden om
PII op het publieke topic te posten, wijst de broker dat af, want het
ACL-profiel van `pub-public` laat alleen `enewable/public/>` toe.

Gebruik `--class public|eu-ops|eu-pii` op elk script om je tot één klasse
te beperken (bijv. voor gericht testen) -- zie elk script se eigen
`--help`/docstring. De 3 klasse-specifieke voorbeeldpayloads staan in
[`sample-payloads/`](sample-payloads/), gedeeld door `stm` en `sdkperf`
(het Python-script genereert zijn payloads in code, zie `publisher.py`).

Zie `../docs/demo-apps.md` voor de volledige toelichting en het
voorgestelde draaiboek voor de live demo.
