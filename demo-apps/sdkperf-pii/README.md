# SDKPerf -- alle 3 dataklassen (via één tool)

Gebruikt [SDKPerf](https://docs.solace.com/API/SDKPerf/SDKPerf.htm)
(`sdkperf_java`) om Enewable-data te publiceren. Publiceert standaard **alle
drie** de dataklassen -- publiek, niet-persoonlijk EU, en gevoelige PII
(individuele slimme-meterstanden gekoppeld aan een klant-ID) -- elk met zijn
eigen topic en zijn eigen scoped client-username, om te laten zien dat de
bestemming door de topic wordt bepaald, niet door de tool (zie
`../README.md`). Verifieer expliciet dat de PII-berichten niet op de AWS-
of Azure-broker verschijnen (analoog aan `#noexport` in de presentatie).

## Installatie

Download SDKPerf voor je platform van
[Solace Developer Tools](https://www.solace.dev/) / de Solace Cloud
"Try Me!"-downloadlink, en zet `sdkperf_java.sh` (of `.bat`) op je PATH, of
zet het volledige pad in `SDKPERF_BIN` in `local-broker/.env`.

## Gebruik

```bash
./publish-pii.sh
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
(`NL`/`BE`/`LU`/`DE`/`FR`). Dit betekent dat `sdkperf_java.sh` voor de
public-klasse COUNT keer los wordt aangeroepen (één bericht per keer),
i.p.v. één `-mn=N`-batch zoals eu-ops/eu-pii nog doen -- dus zichtbaar
langzamer per bericht (JVM-opstarttijd elke keer), maar nodig voor echte
variatie. Verlaag `COUNT` (bijv. `5`) voor een snellere pas als de
demotijd beperkt is. Beperk tot één klasse met `--class`:

```bash
./publish-pii.sh --class eu-pii 20
```

Kernidee van het commando per klasse (zie het script voor de volledige,
geparametriseerde versie):

```bash
sdkperf_java.sh -cip=localhost:55554 -cu=pub-eu-pii@enewable -cp="$PUB_EU_PII_PASSWORD" \
  -ptl=enewable/eu/pii/meter/reading/ENW-NL-000482 -pal=../sample-payloads/eu-pii.json \
  -mn=20 -mr=2 -mt=direct -md   # -md drukt elk verzonden bericht af, handig live op het podium
```

(Het laatste topicniveau, `ENW-NL-000482`, is de `customerId` uit
`../sample-payloads/eu-pii.json` -- het script leest dit veld zelf uit
het bestand in plaats van het hardcoded te laten staan.)

(`-pal` = payload-attachment-list: stuurt de ruwe inhoud van het bestand
als binary attachment. Niet `-mf` -- die optie bestaat niet en geeft
"Unrecognized option: -mf", bevestigd door Emil op een echte SDKPerf
8.4.17.5-installatie.)

> Let op: dit is met opzet **fictieve, gesynthetiseerde** klantdata (zie
> `../sample-payloads/eu-pii.json`) -- gebruik nooit echte persoonsgegevens
> in een demo.

Verifieer op de AWS-, Azure- en STACKIT-broker (Solace Cloud console, tab
"Try Me!" van elke service) dat elke klasse alleen op zijn EIGEN
cloud-broker aankomt, en nergens anders.
