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
`pub-eu-pii`), elk 20 berichten. Dit script bouwt de topic per verstuurd
bericht opnieuw op, want de veldwaarden rouleren hier per bericht:
`type`/`market` voor publiek (3 types x 5 markten, bijv.
`.../price/intraday-price/BE`), `postcodeArea` voor eu-ops (10 waarden,
`1000-NL` .. `9700-NL`), `customerId` voor eu-pii (20 fictieve waarden,
bijv. `enewable/eu/pii/meter/reading/ENW-NL-000917` op het ene bericht,
`.../ENW-NL-002203` op het volgende). `stm`/SDKPerf doen dit inmiddels op
dezelfde manier (COUNT losse aanroepen i.p.v. één batch), al lezen zij
hun basispayload uit een statisch JSON-bestand in `sample-payloads/` in
plaats van die in code te genereren. Beperk tot één klasse met
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
