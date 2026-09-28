# SKILLS.md

Concrete, herbruikbare recepten en oplossingen die tijdens het bouwen van
deze demo zijn ontdekt. Check dit bestand vóórdat je een probleem opnieuw
uitzoekt dat hier al is opgelost -- de meeste van deze punten kwamen uit
een echte, tijdrovende foutmelding. Zie `AGENTS.md` voor de bredere
architectuur- en werkconventies, `PLAN.md` voor de volledige geschiedenis
per punt (verwijzingen tussen haakjes).

## Een demo-app-script dry-run testen zonder live broker

`stm-public/publish-public.sh` en `sdkperf-pii/publish-pii.sh` roepen een
extern binary aan (`stm`, `sdkperf_java.sh`). Om topic/payload-logica te
testen zonder een echte broker nodig te hebben:

1. **Kopieer de HELE `demo-apps/`-map** naar een temp-locatie (bijv.
   `/tmp/demo-apps-test`), niet alleen het script -- `PAYLOAD_DIR` wordt
   relatief t.o.v. `SCRIPT_DIR` berekend, dus een los gekopieerd script
   kan zijn `sample-payloads/*.json` niet meer vinden en faalt stil (elk
   veld valt terug op zijn `:=unknown`-default, wat een test vals laat
   slagen).
2. Maak een fake binary in een eigen bin-map (bijv. `/tmp/fakebin/stm` of
   `/tmp/fakebin/sdkperf_java.sh`) die de relevante argumenten (`--topic`/
   `--file` resp. `-ptl=`/`-pal=`) parseert en teruglogt/echoot.
3. Draai het echte (gekopieerde) script met
   `PATH="/tmp/fakebin:$PATH"` ervoor.

## De no-jq-fallback testen

`json_field()`/`render_payload()` gebruiken `jq` als dat er is, anders een
grep/sed-fallback. Om de fallback-tak echt te testen (niet alleen aan te
nemen dat hij werkt):

- Zet **niet** simpelweg `PATH="/nonexistent"` -- dat sloopt ook `grep`/
  `sed` zelf en geeft een vals-negatieve "lege waarde"-uitkomst die niets
  zegt over de fallback-logica.
- Bouw in plaats daarvan een eigen bin-map met symlinks naar alleen de
  benodigde core-tools (`grep`, `sed`, `cp`, `mv`, `mktemp`, `cat`, `rm`,
  `tr`, `bash`, ...), met `jq` bewust weggelaten.
- Bevestig vóór de test expliciet dat `jq` echt afwezig is:
  `command -v jq; echo $?` (moet 1 geven).

## SDKPerf: de juiste vlaggen

- Payload uit een bestand versturen: **`-pal=<file>`** (payload-attachment-
  list, stuurt de ruwe bestandsinhoud als binary attachment). Dit is NIET
  officieel gedocumenteerd door Solace -- alleen gevonden via een
  Solace-communitythread ("sdkperf file input format"). `-sdm`
  (structured-data-message) is iets anders: dat vereist een specifiek
  getypeerd key=value-formaat, geen ruwe JSON.
- **`-mf` bestaat niet** -- geeft `Parsing failed. Reason: Unrecognized
  option: -mf`. Dit was een aanname die niet klopte; altijd verifiëren
  tegen de officiële Solace Command-Line-Options-documentatie vóórdat je
  een vlag aanneemt.
- `-ptl` (topic list) accepteert officieel een lijst met meerdere topics;
  `-pal` is (zoals hierboven) niet officieel gedocumenteerd, dus neem NIET
  aan dat `-pal` ook een lijst-syntax ondersteunt zoals `-ptl` dat doet --
  gebruik in plaats daarvan een lus van losse aanroepen met `-mn=1` per
  bericht als je per bericht een andere payload nodig hebt (zie
  `PLAN.md` sectie 13, punt 37 voor de volledige afweging).
- Basis: `-cip`, `-cu`, `-cp`, `-ptl`, `-pal`, `-mt`, `-mn`, `-mr`, `-md`
  (drukt elk verzonden bericht af -- handig live op het podium).

## Solace Try-Me CLI (`stm`)

- Het subcommando is **`stm send`**, niet `stm publish` (bestaat niet in
  v1.0.0).
- `stm send` publiceert standaard **PERSISTENT**, wat de lokale broker
  afwijst ("Sending guaranteed message is not allowed by router for this
  client") omdat het `default`-clientprofiel bewust
  `allowGuaranteedMsgSendEnabled: false` heeft. Voeg altijd expliciet
  `--delivery-mode DIRECT` toe.

## Sunburst Topic Explorer (https://explorer.solace.dev/) aan de praat krijgen

- Verbind met `ws://localhost:8008`, VPN `enewable`, met het losse
  read-only `monitor`-account (niet een van de `pub-*`-accounts, die
  mogen niet subscriben).
- **Het "Topic(s)"-veld staat standaard op
  `#noexport/>, #noexport/#P2P/>`** (Solace se eigen interne
  gereserveerde prefix, niets met deze demo te maken). Dat geeft
  "Subscription ACL Denied on Topic: #noexport/>" bij Start/Subscribe --
  dit is GEEN ACL-bug, gewoon een client-side UI-veld dat je zelf naar
  `enewable/>` moet wijzigen vóór je op Start/Subscribe klikt.

## Een nieuw dynamisch topic-veld toevoegen aan alle 3 tools consistent

Patroon (zie `PLAN.md` sectie 13, punten 36-38 voor de volledige
geschiedenis):

1. Basiswaarde staat in `demo-apps/sample-payloads/<class>.json` (bash-
   tools) of wordt in code gegenereerd (Python).
2. Vaste lijst met mogelijke waarden als plain indexed array (bash,
   macOS-bash-3.2-veilig) resp. een module-level lijst (Python).
3. Per bericht een willekeurige waarde kiezen:
   bash: `${ARR[$(( RANDOM % ${#ARR[@]} ))]}`;
   Python: `random.choice(LIST)`.
4. Payload per bericht overschrijven (`render_payload()` in bash: jq-pad
   of sed-fallback; Python: direct in de dict) en de topic per bericht
   opnieuw opbouwen (niet één keer buiten de lus).
5. **Geen broker-wijziging nodig** -- de ACL-exceptions en
   RDP-export-subscriptions staan al op de hele
   `enewable/<klasse>/>`-subtree (zie `AGENTS.md`).
6. Vergeet niet: dit voegt een losse CLI-aanroep per bericht toe voor
   bash-tools (COUNT keer i.p.v. één batch) -- documenteer de
   timing-impact in `docs/demo-apps.md`.

## De Word-samenvatting (`docs/Plan-van-aanpak-DADD2026-Enewable.docx`) herbouwen

1. Bewerk het `build.js`-script (gebruikt de `docx` npm-library) --
   meestal de `topicTable`/`faseTable`/architectuur-bullets.
2. `node build.js` -- schrijft naar
   `/mnt/user-data/outputs/Plan-van-aanpak-DADD2026-Enewable.docx`.
3. Verifieer de nieuwe inhoud programmatisch (niet alleen aannemen dat de
   stringvervanging goed ging): open het `.docx`-bestand als zip en
   controleer `word/document.xml` op de verwachte substrings (let op:
   XML-escaping, bijv. `'` wordt `&apos;`).
4. Lever het bestand met `SendUserFile`, en zet het met
   `device_commit_files` in `docs/` in de repo.

## Vóór elke commit

`grep -rlP "\xc2\xad" --include="*.md" --include="*.sh" --include="*.py" .`
-- vangt onbedoelde soft-hyphen-tekens (`­`) die soms door
copy-paste of editor-autocorrect binnensluipen en onzichtbaar zijn in
normale weergave.
