# TODO

Actuele, geprioriteerde actielijst voor deze demo/presentatie. Dit is het
startpunt om de sessie te sluiten en later weer op te pakken: begin hier,
niet in `PLAN.md`.

- **`PLAN.md`** is het volledige, chronologische logboek (elke stap,
  beslissing, bug en fix, met sectie- en puntnummers) -- raadpleeg dat bij
  twijfel of voor de achtergrond van een item hieronder (verwijzingen
  tussen haakjes).
- **`AGENTS.md`** legt de architectuur- en werkconventies van deze repo uit
  voor wie (mens of AI-coding-agent) de volgende stap oppakt.
- **`SKILLS.md`** bundelt concrete, herbruikbare recepten die tijdens het
  bouwen zijn ontdekt (testmethodes, tool-vlaggen, gotchas) -- check dit
  vóórdat je een probleem opnieuw uitzoekt dat hier al is opgelost.

Laatst bijgewerkt: 07/10/2026.

## Blokkerend -- eerst dit (services verwijderd, nu opnieuw aangemaakt)

- [x] **De 3 Solace Cloud event broker services opnieuw aangemaakt**
      (AWS, Azure, STACKIT) via `cloud-setup/terraform/` -- alle drie
      `Running` (02/10/2026). STACKIT bleek inmiddels een eigen, echte
      publieke `SolacePublic`-regio te hebben (`ske-eu01`, geen
      GCP-interim meer nodig); `service_class_id = "DEVELOPER"`
      bevestigd juist. (`PLAN.md` sectie 13, punt 42; regio-correctie
      naar `ske-eu01` later, zie punt 58.)
- [x] **`local-broker/.env` bijgewerkt**: nieuwe SMF/SEMP-hostnames
      (let op -- STACKIT's domein is nu `messaging.maasgo.net`, niet
      `messaging.solace.cloud`), alle 3 `*_REMOTE_VPN` naar `enewable`,
      nieuwe `*_SEMP_ADMIN_PASSWORD`-waarden. (`PLAN.md` sectie 13,
      punt 42.)
- [x] **Resterende configuratiescripts opnieuw gedraaid** en end-to-end
      herbevestigd (02/10/2026): `configure-remote-bridge-users.sh`,
      `configure-local-broker.sh` en `configure-rdp-export.sh`. Onderweg
      een echte bug gevonden en gefixt in `configure-rdp-export.sh` (de
      restConsumer kreeg nooit een PATCH, bleef op de oude cloud-hosts/
      credentials staan -- zie `PLAN.md` sectie 13, punt 43). Na de fix:
      `stm-public/publish-public.sh` bevestigd op alle 3 cloud-brokers,
      elk op zijn eigen topic (`PLAN.md` sectie 13, punt 44).
- [x] **STACKIT-service opnieuw extern verwijderd, opnieuw aangemaakt
      via Terraform (07/10/2026)** -- dit keer alleen STACKIT geraakt
      (AWS/Azure ongemoeid, bevestigd met `terraform plan`: nul
      drift). Daarbij bleek de eerder aangenomen
      `stackitdemo-stackit-eu01-production` een `SolaceDedicated`/
      Private-Cloud-cluster te zijn, niet de echte publieke
      STACKIT-regio -- gecorrigeerd naar `ske-eu01` (`SolacePublic`).
      Nieuwe servicenaam: `ez-dadd-2026-ske-eu01`. End-to-end
      herbevestigd via de STACKIT "Try Me!"-tab. (`PLAN.md` sectie 13,
      punt 58.)
- [ ] **Verweesde service `ez-dadd-2026-stackit-eu01` opruimen** (op
      `stackitdemo-stackit-eu01-production`, draait nog maar wordt
      niet meer door Terraform gevolgd) -- handmatig verwijderen via
      de Solace Cloud console. (`PLAN.md` sectie 13, punt 58.)

## Moet vóór DADD

- [ ] **Draaiboek oefenen + fallback-opname maken.** Live-timing op het
      podium oefenen en een schermopname van een geslaagde run maken als
      vangnet voor slechte conferentiewifi/hardware (de presentatie zelf
      raadt dit expliciet aan). Video komt later, maar wel vóór DADD.
      (`PLAN.md` sectie 10, fase 6; sectie 11; sectie 13, bullet "Geen
      backup/fallback-materiaal"; sectie 14, punt 9.)
- [x] **De nieuwste variatie-uitbreidingen bevestigd** (Emil, 02/10/2026):
      brede spreiding in markten/types, postcodegebieden en klant-ID's
      zichtbaar gemaakt via de Sunburst Topic Explorer
      (explorer.solace.dev) op de lokale broker. (`PLAN.md` sectie 13,
      punten 35, 37, 38, 47.)
- [x] **Volledige testronde (fase 5) herhaald, stap voor stap**
      (02/10/2026): Broker Manager-check, alle 3 demo-apps elk uitsluitend
      op hun eigen doelbroker (AWS/Azure/STACKIT), en een reguliere
      container-restart + opnieuw draaien van `configure-local-broker.sh`
      + `configure-rdp-export.sh` bevestigd idempotent (geen fouten, geen
      duplicaten). Negative ACL-test (testplan-punt 5) en koude-starttijd
      meten (testplan-punt 7) bewust overgeslagen -- zie "Kan na DADD"
      resp. hierboven waarom. (`PLAN.md` sectie 13, punt 48.)
- [x] **Presentatie in Solace-huisstijl gebouwd**: 14-dia PowerPoint
      (`docs/DADD2026-Enewable-Soevereine-Cloud.pptx`) die het hele proces
      van scratch tot draaiende omgeving beeldend beschrijft, met een
      architectuurdiagram, een 5-staps bouwproces-workflow, 3 "live
      bewijs"-dia's uit de eigen Try-Me!-screenshots van vandaag en de
      Sunburst-taxonomie als visual. (`PLAN.md` sectie 13, punt 49.)
- [x] **Bugfix (deel 1 van 2) -- Content_Types.xml opgeschoond**: bekend
      `pptxgenjs`-pakketdefect (overbodige `Content_Types.xml`-verwijzingen
      naar niet-bestaande `slideMasterN.xml`-onderdelen) opgeschoond na de
      build; opnieuw gevalideerd en herleverd. (`PLAN.md` sectie 13, punt 50.)
- [x] **Bugfix (deel 2 van 2, de echte oorzaak) -- negatieve pijl-hoogte
      in het architectuurdiagram**: `arrow()`-functie in `build-deck.js`
      berekende voor opwaartse pijlen (AWS/Azure) een negatieve shape-hoogte
      (ongeldig OOXML, door LibreOffice stil genegeerd maar door PowerPoint
      geweigerd -- vandaar dat dia's 4+ leeg bleven na "Cancel" op het
      reparatiescherm). Gefixt met `Math.abs()`, deck volledig herbouwd,
      geverifieerd en herleverd. (`PLAN.md` sectie 13, punt 51.)

- [x] **Vóór het publiek maken: volledige audit + opschoning (tekst,
      screenshots, git-geschiedenis)**: de 3 echte Solace Cloud
      mr-connection-hostnamen en 3 echte AWS/Azure/STACKIT-service-ID's uit
      PLAN.md/docs/lokale-broker.md/local-broker/.env.example gehaald, het echte
      IP-adres in de 3 "Bridges"-screenshots en de DMR Cluster
      hostname/cluster-name-velden in de 3 status-screenshots afgedekt, en de
      volledige git-geschiedenis herschreven met git-filter-repo zodat de
      originele waarden nergens meer terug te vinden zijn -- gepusht met git push
      --force (assistent + Emil, 07/10/2026). (`PLAN.md` sectie 13, punt 59;
      `SKILLS.md`.)
- [x] **Repo op GitHub van privé naar publiek gezet** (Emil, 07/10/2026) -
      bevestigd met een anonieme `git fetch` tegen origin (werkt nu zonder
      credentials, wat alleen kan op een publieke repo) dat de remote-HEAD
      exact overeenkomt met de geredigeerde geschiedenis van punt 59.
      (`PLAN.md` sectie 13, punt 59.)

Zie [`docs/demo-notes.md`](docs/demo-notes.md) voor de twee punten die
expliciet in de talk zelf benoemd moeten worden (Azure = Amerikaanse
hyperscaler ondanks EU-locatie; cloud-brokers bewust in public clusters)
-- geen code-werk, wel onthouden tijdens het praatje.

## Kan na DADD (bewuste scope-keuzes voor nu)

- [ ] **Negative ACL-test uitvoeren** (testplan-punt 5): bewust een
      "verkeerde" client-username op een andere klasse se topic laten
      publiceren en bevestigen dat de broker dit weigert -- laat de
      governance-garantie zien, niet alleen de happy path. Verplaatst
      hierheen op Emils verzoek (02/10/2026) -- geen blocker voor DADD
      zelf. (`PLAN.md` sectie 12, punt 5.)
- [ ] Automatische provisioning van alle 4 brokers in één commando
      (Terraform/Ansible i.p.v. losse scripts). De 3 cloud-services gaan nu
      via Terraform (zie bovenaan dit bestand) en zijn succesvol
      aangetoond herhaalbaar (02/10/2026) -- de lokale broker (Docker +
      SEMP-config) zit daar nog niet in. (`PLAN.md` sectie 13, bullet
      "Geen automatische provisioning".)
- [ ] Monitoring/observability (Solace metrics/Prometheus i.p.v. alleen
      Broker Manager). (`PLAN.md` sectie 13, bullet "Geen
      monitoring/observability".)
- [ ] Geautomatiseerde tests/CI (`bash -n`/`shellcheck`/`python -m
      py_compile` op elke push) -- klein, waardevol, niet demo-kritisch.
      (`PLAN.md` sectie 13, bullet "Geen geautomatiseerde tests/CI".)
- [ ] Echt secretsbeheer (1Password CLI, `sops`, Solace Cloud
      credential-rotatie) i.p.v. `.env`-bestanden -- pas relevant bij een
      teamrepo of langere levensduur. (`PLAN.md` sectie 13, bullet
      "Geheimenbeheer".)
- [ ] Architecturaal preciezere `#noexport`-weergave via een DMR-cluster
      i.p.v. queues/RDP's -- bewust buiten scope voor deze eerste versie.
      (`PLAN.md` sectie 13, bullet over DMR-cluster/`#noexport`.)

## Housekeeping (gecheckt, geen actie nodig)

- **Geen losse TODO's/FIXME's in code of configuratie** buiten wat
  hierboven al staat (gecontroleerd met `git grep` op `TODO|FIXME|XXX|
  HACK` over alle getrackte `.sh`/`.py`/`.json`/`.env*`-bestanden,
  28/09/2026).
- **`local-broker/.env` bevat alle 42 sleutels uit `.env.example`**, elk
  met een echte waarde (geen placeholders/lege velden) (gecontroleerd
  28/09/2026).
- **`demo-apps/python-eu-nonpersonal/.env.example`** heeft bewust geen
  eigen `.env` -- `publisher.py` valt automatisch terug op
  `local-broker/.env`, dat alle benodigde sleutels al bevat.
- **`cloud-setup/solace-cloud-api/.env.example`** heeft geen eigen `.env`
  -- alleen nodig voor `create-service.sh` (Fase 2/3, al ✅ afgerond); pas
  weer relevant als er ooit een nieuwe Solace Cloud-service moet worden
  aangemaakt. Geen actie nu.
