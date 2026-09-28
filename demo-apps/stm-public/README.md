# stm -- alle 3 dataklassen (via één tool)

Gebruikt [Solace Try-Me CLI](https://github.com/SolaceLabs/solace-tryme-cli)
(`stm`) om Enewable-data te publiceren. Publiceert standaard **alle drie**
de dataklassen -- publiek, niet-persoonlijk EU, en gevoelige PII -- elk met
zijn eigen topic en zijn eigen scoped client-username, om te laten zien dat
de bestemming door de topic wordt bepaald, niet door de tool (zie
`../README.md`).

## Installatie

```bash
npm install -g solace-tryme-cli
stm --version
```

## Gebruik

```bash
./publish-public.sh
```

Publiceert, in volgorde: publiek (`enewable/public/market/price/<type>/
<market>`, als `pub-public`) -> niet-persoonlijk EU
(`enewable/eu/ops/grid/load/<type>/<postcodeArea>`, als `pub-eu-ops`) ->
gevoelige PII (`enewable/eu/pii/meter/reading/<customerId>`, als
`pub-eu-pii`).

Voor **eu-ops**/**eu-pii** komen de `<...>`-delen uit het vaste
`../sample-payloads/<class>.json`-bestand (met `jq`, of een
grep/sed-fallback als `jq` niet geïnstalleerd is). Voor **public**
variëren `<type>` en `<market>` per bericht -- willekeurig gekozen uit 3
types (`day-ahead-price`/`intraday-price`/`imbalance-price`) en 5 markten
(`NL`/`BE`/`LU`/`DE`/`FR`), bijv. `.../price/intraday-price/BE` op het
ene bericht, `.../price/day-ahead-price/DE` op het volgende. Dit betekent
dat `stm send` voor de public-klasse COUNT keer los wordt aangeroepen
(één bericht per keer, telkens met een eigen topic + payload), i.p.v. één
`--count N`-batch zoals eu-ops/eu-pii nog doen -- dus zichtbaar
langzamer per bericht (Node-opstarttijd elke keer), maar nodig voor
echte variatie. Verlaag `COUNT` (bijv. `5`) voor een snellere pas als de
demotijd beperkt is. Beperk tot één klasse met `--class`:

```bash
./publish-public.sh --class eu-pii        # alleen de PII-klasse
./publish-public.sh --class public 20     # alleen publiek, 20 berichten
```

Of handmatig, één klasse, één bericht:

```bash
stm send \
  --url ws://localhost:8008 \
  --vpn enewable \
  --username pub-public --password "$PUB_PUBLIC_PASSWORD" \
  --topic enewable/public/market/price/day-ahead-price/NL \
  --file ../sample-payloads/public.json \
  --delivery-mode DIRECT
```

Let op `--delivery-mode DIRECT`: `stm send` publiceert standaard
PERSISTENT (guaranteed), wat de lokale broker afwijst ("Sending
guaranteed message is not allowed by router for this client") omdat het
`default` client-profile bewust `allowGuaranteedMsgSendEnabled: false`
heeft -- deze demo is expliciet op DIRECT-publiceren + automatische
queue-promotion gebouwd (zie `PLAN.md` sectie 13, punt 22).

Verifieer op de AWS-, Azure- en STACKIT-broker (Solace Cloud console, tab
"Try Me!" van elke service) dat elke klasse alleen op zijn EIGEN
cloud-broker aankomt, en nergens anders.
