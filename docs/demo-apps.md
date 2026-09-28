# Demo-apps: toelichting en draaiboek

Zie `../demo-apps/README.md` voor het overzicht van de drie tools. Dit
document geeft het voorgestelde draaiboek voor de live demo, gespiegeld aan
slide 23 ("Data that can't cross the border") van de sovereign-cloud-deck.

**Herzien (28/09/2026, Emil):** elk van de 3 tools publiceert nu **alle
drie** de dataklassen in één run (was: één klasse per app) -- zie
`../demo-apps/README.md`. Dit maakt de kernboodschap scherper: het is de
**topic** die de bestemming bepaalt, niet welke tool je toevallig draait.
Het draaiboek hieronder is bijgewerkt om dat te benutten.

## Voorgesteld draaiboek (aansluitend op de presentatie)

1. **Eén tool, drie bestemmingen**: draai `demo-apps/stm-public/publish-public.sh`
   (zonder `--class`) en laat de 3 "Try Me!"-tabs van AWS, Azure en STACKIT
   naast elkaar open staan. Boodschap: dit is dezelfde tool, dezelfde
   sessie -- alleen de topic (en de bijbehorende, ACL-gescoped identiteit)
   bepaalt waar elk bericht landt.
   - Eerst **publiek** (dagprijzen) -> alleen AWS: onschuldige data mag
     gewoon naar de hyperscaler.
   - Dan **niet-persoonlijk EU** (netbelasting) -> alleen Azure: EU-gebonden,
     maar niet privacygevoelig genoeg voor de zwaarste route.
   - Dan **gevoelige PII** (meterstanden) -> alleen STACKIT, expliciet
     *niet* op AWS of Azure -- dit is het "aha"-moment, verdient de meeste
     stilte/nadruk (net als slide 23: "watch it stay" vs. "share the safe
     part").
2. **Herhaal desgewenst met een andere tool** (`python-eu-nonpersonal/publisher.py`
   of `sdkperf-pii/publish-pii.sh`, ook zonder `--class`) om te laten zien
   dat dit geen toevalstreffer van één specifieke tool is -- alle 3 tools
   gedragen zich identiek, want de handhaving zit op de broker (ACL +
   topic-routering), niet in de tool.
3. Optioneel, als er tijd is: laat in Broker Manager van de lokale broker de
   3 REST Delivery Points en hun queue message-counts zien, als "achter de
   schermen"-bewijs dat dit door topic-routering komt, niet door drie
   losse handmatige acties. Nog visueler: [Sunburst Topic
   Explorer](https://explorer.solace.dev/) (zie `../README.md`, "Verkeer
   visualiseren") laat live zien hoe elke klasse zijn eigen tak in de
   topic-boom krijgt -- de topics zijn dynamisch (bijv.
   `enewable/eu/pii/meter/reading/<customerId>`), dus de boom groeit
   zichtbaar per verstuurd bericht in plaats van steeds hetzelfde ene
   topic te herhalen.
4. Optioneel, voor een dieper punt: draai één tool met `--class` beperkt tot
   één klasse (bijv. `--class public`) om te laten zien dat je ook gericht
   één klasse kan testen/isoleren -- handig voor troubleshooting, niet
   nodig voor de kernboodschap.

## Timing

Punt 1 (één tool, drie bestemmingen) duurt ongeveer 60-90 seconden in
totaal (drie klassen achter elkaar, elk een paar berichten) en bevat zowel
de "onschuldige data mag" als het "aha"-moment binnen dezelfde run. Punt 2
is optioneel en kan achterwege blijven als de tijd beperkt is -- punt 1
draagt de hoofdboodschap al. Totaal ruim binnen de 4 minuten die de
presentatie zelf voor de live demo reserveert (zie de sprekersnotities bij
slide 23 van de deck).

**Let op: dit geldt nu voor ALLE 3 klassen**, niet meer alleen publiek
(sinds ook `eu-ops`/`eu-pii` per bericht variëren -- 10 `postcodeArea`-/
20 `customerId`-waarden, zie `../demo-apps/README.md`): `stm`/
`sdkperf_java.sh` roepen nu voor ELKE klasse COUNT keer los aan (één
bericht per keer) in plaats van één batch-aanroep, dus een volledige
default-run (10 voor stm, 20 voor SDKPerf, x 3 klassen) kan op het
podium duidelijk langer duren dan de 60-90s-inschatting hierboven,
vooral bij SDKPerf (JVM-opstarttijd per aanroep, x 60 aanroepen bij de
default). Gebruik voor de live demo een laag `COUNT` over de hele run
(bijv. `./publish-public.sh 5`) of `--class <klasse> 5` om één klasse
gericht te tonen -- 5 berichten laat, dankzij de willekeurige keuze uit
de betreffende lijst, meestal al meerdere verschillende combinaties
zien.

## Fallback

Zoals de presentatie zelf ook aanraadt voor de eigen demo: neem vooraf een
schermopname van een geslaagde run op als fallback voor het geval de
conferentiewifi/hardware niet meewerkt. Zie `PLAN.md`, sectie
"Draaiboek voor de live demo".
