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
