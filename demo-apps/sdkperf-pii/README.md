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

Publiceert, in volgorde: publiek (`enewable/public/market/price`, als
`pub-public`) -> niet-persoonlijk EU (`enewable/eu/ops/grid/load`, als
`pub-eu-ops`) -> gevoelige PII (`enewable/eu/pii/meter/reading`, als
`pub-eu-pii`). Beperk tot één klasse met `--class`:

```bash
./publish-pii.sh --class eu-pii 20
```

Kernidee van het commando per klasse (zie het script voor de volledige,
geparametriseerde versie):

```bash
sdkperf_java.sh -cip=localhost:55554 -cu=pub-eu-pii@enewable -cp="$PUB_EU_PII_PASSWORD" \
  -ptl=enewable/eu/pii/meter/reading -mf=../sample-payloads/eu-pii.json \
  -mn=20 -mr=2 -mt=direct -md   # -md drukt elk verzonden bericht af, handig live op het podium
```

> Let op: dit is met opzet **fictieve, gesynthetiseerde** klantdata (zie
> `../sample-payloads/eu-pii.json`) -- gebruik nooit echte persoonsgegevens
> in een demo.

Verifieer op de AWS-, Azure- en STACKIT-broker (Solace Cloud console, tab
"Try Me!" van elke service) dat elke klasse alleen op zijn EIGEN
cloud-broker aankomt, en nergens anders.
