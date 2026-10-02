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

Laatst bijgewerkt: 02/10/2026.

## Blokkerend -- eerst dit (services verwijderd, nu opnieuw aangemaakt)

- [x] **De 3 Solace Cloud event broker services opnieuw aangemaakt**
      (AWS, Azure, STACKIT) via `cloud-setup/terraform/` -- alle drie
      `Running` (02/10/2026). STACKIT bleek inmiddels een eigen, echte
      `SolaceDedicated`-datacenter te hebben (geen GCP-interim meer
      nodig); `service_class_id = "DEVELOPER"` bevestigd juist.
      (`PLAN.md` sectie 13, punt 42.)
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
- [ ] **Volledige testronde (fase 5) herhalen, stap voor stap**, niet
      vertrouwen op de eerdere (gebundelde) validatie via
      `run-demo-loop.sh` -- sindsdien zijn er meerdere functionele
      wijzigingen bijgekomen (alle 3 klassen per run, dynamische topics,
      variatie-uitbreidingen). Negative ACL-test (testplan-punt 5) en
      koude-starttijd meten (testplan-punt 7) horen hier NIET meer bij --
      zie "Kan na DADD" resp. hieronder waarom. (`PLAN.md` sectie 10,
      fase 5; sectie 12.)

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
