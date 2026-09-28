# Python-script -- alle 3 dataklassen (via één tool)

Publiceert Enewable-data naar de lokale broker met de
[Solace PubSub+ Python API](https://docs.solace.com/API/API-Developer-Guide-Python/).
Publiceert standaard **alle drie** de dataklassen -- publiek,
niet-persoonlijk EU, en gevoelige PII -- elk met zijn eigen topic en zijn
eigen scoped client-username (elke klasse opent zijn eigen verbinding, een
Solace-identiteit hoort bij precies één client-username), om te laten zien
dat de bestemming door de topic wordt bepaald, niet door de tool (zie
`../README.md`).

## Installatie

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

## Gebruik

```bash
cp .env.example .env   # of laat leeg en hergebruik ../../local-broker/.env
python publisher.py
```

Publiceert, in volgorde: publiek (`enewable/public/market/price/<type>/
<market>`, als `pub-public`) -> niet-persoonlijk EU
(`enewable/eu/ops/grid/load/<type>/<postcodeArea>`, als `pub-eu-ops`) ->
gevoelige PII (`enewable/eu/pii/meter/reading/<customerId>`, als
`pub-eu-pii`), elk 20 berichten. Anders dan `stm`/SDKPerf (die een
statisch JSON-bestand lezen) bouwt dit script de topic per verstuurd
bericht opnieuw op, want `postcodeArea` en `customerId` rouleren hier per
bericht (bijv. `enewable/eu/pii/meter/reading/ENW-NL-000917` op het ene
bericht, `.../ENW-NL-002203` op het volgende). Beperk tot één klasse met
`--class`:

```bash
python publisher.py --class eu-ops --count 20 --interval 1
```

Verifieer op de AWS-, Azure- en STACKIT-broker (Solace Cloud console, tab
"Try Me!" van elke service) dat elke klasse alleen op zijn EIGEN
cloud-broker aankomt, en nergens anders.

## Waarom een los script i.p.v. stm/SDKPerf?

Dit demonstreert de derde manier van dataproductie uit de opdracht (naast
`stm` en SDKPerf): een eigen applicatie die de Solace-taal-API rechtstreeks
gebruikt, zoals een echt Enewable-backend-systeem dat zou doen. Qua
governance is dit script bewust identiek behandeld aan de andere twee: voor
elke klasse gebruikt het een eigen, met een ACL-profiel beperkte
client-username die alleen op die klasse se eigen topic-subtree mag
publiceren.
