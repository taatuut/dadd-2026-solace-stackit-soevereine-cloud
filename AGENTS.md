# AGENTS.md

Context en werkconventies voor een AI-coding-agent (of nieuwe menselijke
bijdrager) die aan deze repo werkt. Lees dit vóór je code of configuratie
wijzigt. Zie ook `TODO.md` (actuele actielijst), `PLAN.md` (volledig
logboek) en `SKILLS.md` (herbruikbare recepten/oplossingen).

## Wat dit is

Een demo-opzet voor een DADD 2026-presentatie over soevereine,
event-driven infrastructuur: één lokale Solace-broker ontvangt drie
dataklassen (publiek, niet-persoonlijk EU, gevoelige PII) van drie
demo-apps, en levert elke klasse - puur op basis van de topic waarop
gepubliceerd wordt - automatisch aan de juiste (en alleen de juiste)
cloud-broker (AWS, Azure, STACKIT). Zie `PLAN.md` sectie 1-3 voor de
volledige context en `README.md` voor de stap-voor-stap-handleiding.

## Architectuurfeiten die je MOET kennen vóór je iets wijzigt

- **Alle ACL-publish-exceptions en alle RDP-export-queue-subscriptions
  gebruiken het `enewable/<klasse>/>`-multi-level-wildcard-patroon**
  (`configure-local-broker.sh` resp. `configure-rdp-export.sh`), niet een
  exacte topic-string. Extra topic-niveaus toevoegen (bijv. een nieuw
  dynamisch veld) vereist dus GEEN broker-herconfiguratie - verifieer dit
  altijd met `grep` in die twee scripts vóórdat je een topic-wijziging
  aanneemt dat wel te vereisen.
- De 3 publish-only client-usernames (`pub-public`/`pub-eu-ops`/
  `pub-eu-pii`) mogen NIET subscriben. Het losse, read-only
  `monitor`-account (voor Sunburst Topic Explorer e.d.) mag alleen
  subscriben, nooit publiceren. Doorbreek deze scheiding niet.
- Topics zijn dynamisch: elke tool voegt echte veldwaarden uit het
  bericht toe aan de topic (bijv. `.../price/intraday-price/BE`), niet
  een vaste string. Zie `PLAN.md` sectie 13, punten 36-38 voor de volledige
  geschiedenis van deze wijziging, inclusief WAAROM dat zonder
  broker-wijziging kan (zie het wildcard-punt hierboven).
- **macOS bash 3.2-compatibiliteit**: gebruik nooit `declare -A` in de
  bash-scripts (`stm-public/publish-public.sh`,
  `sdkperf-pii/publish-pii.sh`, `local-broker/scripts/run-demo-loop.sh`,
  de `semp/*.sh`-scripts) - plain indexed arrays (`ARR=(a b c)`) wel.
  Emil test op macOS met de systeem-bash (3.2), niet een nieuwere via
  Homebrew.
- `stm`/`sdkperf`-scripts lezen basisvelden uit
  `demo-apps/sample-payloads/*.json` met `jq` als dat beschikbaar is,
  anders een grep/sed-fallback - **iedere wijziging aan hoe een veld
  wordt gelezen/overschreven moet BEIDE paden blijven ondersteunen** en
  beide moeten getest worden (zie `SKILLS.md`, "No-jq-fallback testen").

## Documentatie- en commit-conventie

Deze repo heeft een strikte gewoonte, zichtbaar in `git log`: na elke
functionele wijziging worden in dezelfde commit meegenomen:

1. De relevante code/config.
2. `PLAN.md` - een nieuw genummerd punt in sectie 13 ("Wat ontbreekt of
   beter kan") met: wat er is gewijzigd, waarom, welke bestanden, en hoe
   het is geverifieerd (dry-run-details, testresultaten). Dit is het
   primaire, meest volledige logboek - bij twijfel is `PLAN.md` de
   waarheid, niet een samenvatting elders.
3. De betrokken `README.md`-bestanden (root + per demo-app) en
   `docs/*.md`, zodat er geen verouderde claims blijven staan (bijv. "klasse
   X blijft batchen" nadat dat niet meer klopt).
4. De Word-samenvatting `docs/Plan-van-aanpak-DADD2026-Enewable.docx`
   (gegenereerd uit een `build.js`-script, zie `SKILLS.md`).
5. Een soft-hyphen-sweep (`grep -rlP "\xc2\xad" --include="*.md"
   --include="*.sh" --include="*.py" .`) vóór het committen.
6. Eén git-commit met een Nederlandse, op-de-inhoud-gerichte
   commit-message (wat + waarom, niet alleen wat).

Volg dit patroon ook als jij de wijziging doet. Sla geen van deze stappen
over "om tijd te besparen" - inconsistente documentatie is in deze repo
al meermaals een reële bron van verwarring geweest.

## Taal

Documentatie (`PLAN.md`, `TODO.md`, dit bestand, `SKILLS.md`, `docs/`,
`README.md`) is in het Nederlands. Code en configuratie (scripts, JSON,
commentaar daarin) is in het Engels. Houd je aan welke taal een bestand al
gebruikt.

## Secrets

`local-broker/.env` (en de losse `.env`-bestanden onder `demo-apps/*` en
`cloud-setup/solace-cloud-api/`) staan in `.gitignore` en bevatten echte
wachtwoorden/tokens - commit deze NOOIT en zet geen echte waarden in een
`.env.example`. Als je een nieuwe configuratiewaarde toevoegt, voeg de
sleutel (met een placeholder) toe aan het bijbehorende `.env.example` EN
vraag de gebruiker om de echte waarde in zijn eigen `.env` te zetten -
schrijf zelf nooit een verzonnen waarde in een echt `.env`-bestand.

## Stapsgewijze procedures (installaties, deploys, console-acties)

Wanneer Emil door een procedure geleid wordt die hij zelf moet uitvoeren
(een CLI installeren, `terraform apply` draaien, iets in een console
aanklikken) - geef **één instructie tegelijk**, niet de hele lijst
vooruit. Wacht zijn terugkoppeling af (gelukt, of de foutmelding) en geef
pas daarna de volgende stap. Reden: dit soort procedures loopt in de
praktijk zelden in één keer goed (zie bijv. `SKILLS.md`, "Terraform CLI
installeren op macOS" - de eerste aanname bleek al fout), en een hele
lijst vooruit geven betekent dat een foute vroege stap pas laat opvalt,
met vervolgstappen die op een verkeerde aanname voortbouwen. Dit geldt
ook als de assistent de volgende stappen al kan voorbereiden (bijv. een
bestand alvast invullen) - het voorbereiden mag vooruitlopen, de
instructies AAN Emil niet.

**Nooit een inline `#`-commentaar op dezelfde regel als een commando dat
Emil moet kopiëren-plakken.** zsh (macOS-default) behandelt een `#` in een
interactieve shell NIET automatisch als commentaar (zie README.md,
"Problemen oplossen") - `terraform version   # >= 1.5 verwacht` werd
letterlijk uitgevoerd als `terraform version` met een output-redirect naar
een bestand genaamd `=` (uit de `>=`), wat een leeg `=`-bestand in de
repo-root opleverde. Zet toelichting op een eigen regel erboven, nooit
achter het commando.

## Waar te beginnen

- Nieuwe sessie, wil je weten wat er nog moet gebeuren? -> `TODO.md`.
- Wil je de volledige geschiedenis/reden achter een beslissing? ->
  `PLAN.md` (zoek op sectienummer of puntnummer).
- Sta je voor een probleem dat hier waarschijnlijk al is opgelost
  (SDKPerf-vlaggen, dry-run zonder broker, Sunburst-gotcha's, ...)? ->
  `SKILLS.md`.
- Wil je de demo zelf draaien of installeren? -> `README.md`.
