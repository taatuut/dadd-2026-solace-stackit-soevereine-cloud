# SDKPerf -- gevoelige PII-data (STACKIT)

Gebruikt [SDKPerf](https://docs.solace.com/API/SDKPerf/SDKPerf.htm)
(`sdkperf_java`) om gevoelige klantdata te publiceren: individuele
slimme-meterstanden gekoppeld aan een klant-ID. Dit is de klasse die in de
demo **uitsluitend** naar STACKIT mag (analoog aan `#noexport` in de
presentatie) -- verifieer expliciet dat deze berichten niet op de AWS- of
Azure-broker verschijnen.

## Installatie

Download SDKPerf voor je platform van
[Solace Developer Tools](https://www.solace.dev/) / de Solace Cloud
"Try Me!"-downloadlink, en zet `sdkperf_java.sh` (of `.bat`) op je PATH, of
pas het pad in `publish-pii.sh` aan.

## Gebruik

```bash
./publish-pii.sh
```

Kernidee van het commando (zie het script voor de volledige, geparametriseerde
versie):

```bash
sdkperf_java.sh -cip=localhost:55554 -cu=pub-eu-pii@enewable -cp="$PUB_EU_PII_PASSWORD" \
  -ptl=enewable/eu/pii/meter/reading -mn=20 -mr=2 -mt=direct \
  -md   # -md drukt elk verzonden bericht af, handig live op het podium
```

> Let op: dit is met opzet **fictieve, gesynthetiseerde** klantdata (zie
> `sample-payload.json`) -- gebruik nooit echte persoonsgegevens in een demo.
