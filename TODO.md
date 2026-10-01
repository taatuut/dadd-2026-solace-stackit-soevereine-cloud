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

Laatst bijgewerkt: 01/10/2026.

## Blokkerend -- eerst dit (services verwijderd)

- [ ] **De 3 Solace Cloud event broker services opnieuw aanmaken** (AWS,
      Azure, STACKIT -- verwijderd, 01/10/2026). Nu als "Developer
      100"-tier, in twee Solace Cloud-organisaties (AWS+Azure samen in de
      ene, STACKIT in de andere) i.p.v. de eerdere Enterprise-250-HA-klasse
      in één org. Nieuwe Terraform-opzet staat in
      [`cloud-setup/terraform/`](cloud-setup/terraform/) (zie dat
      README.md voor de volledige stappen -- moet door Emil zelf gedraaid
      worden, netwerktoegang vanuit de sessie is geblokkeerd). Openstaande
      aannames die Emil moet bevestigen vóór `terraform apply`: de 2
      API-tokens + Home-Cloud base_urls, de 3 `datacenterId`-waarden, de
      exacte schrijfwijze van `service_class_id` ("DEVELOPER" vs.
      "developer"), en of STACKIT inmiddels echt GA is (zie de
      STACKIT-GA-check hieronder -- zo niet, interim-GCP-datacenter
      gebruiken zoals voorheen). (`PLAN.md` sectie 13, punt 40.)
- [ ] **Na het aanmaken: `local-broker/.env` volledig bijwerken** (alle
      `AWS_*`/`AZURE_*`/`STACKIT_*`-sleutels -- nieuwe hostnames, VPN-naam
      `enewable`, nieuwe SEMP-admin-credentials) en daarna
      `cloud-setup/solace-cloud-api/configure-remote-bridge-users.sh`,
      `local-broker/semp/configure-local-broker.sh` en
      `configure-rdp-export.sh` opnieuw draaien. Zie
      `cloud-setup/terraform/README.md`, "Na terraform apply", voor de
      volledige sequentie. Niets in deze lijst hieronder kan opnieuw
      bevestigd worden vóórdat dit is gedaan.

## Moet vóór DADD

- [ ] **Draaiboek oefenen + fallback-opname maken.** Live-timing op het
      podium oefenen en een schermopname van een geslaagde run maken als
      vangnet voor slechte conferentiewifi/hardware (de presentatie zelf
      raadt dit expliciet aan). (`PLAN.md` sectie 10, fase 6; sectie 11;
      sectie 13, bullet "Geen backup/fallback-materiaal"; sectie 14,
      punt 9.)
- [ ] **De nieuwste variatie-uitbreidingen echt bevestigen op een cloud-
      broker**, niet alleen via dry-run: de type/market-variatie (punt 37),
      de postcodeArea/customerId-variatie (punt 38) en de `-pal`-fix
      (punt 35) zijn tot nu toe alleen getest met nep-`stm`/
      nep-`sdkperf_java.sh`-binaries. Minstens één echte run per tool,
      controleren in de Solace Cloud "Try Me!"-tabs. (`PLAN.md` sectie 13,
      punten 35, 37, 38.)
- [ ] **STACKIT GA-check.** Kort vóór de repetitie/DADD checken of STACKIT
      inmiddels als eigen datacenter-optie in Solace Cloud staat (i.p.v.
      de GCP europe-west1-interim-stand-in) en zo ja overstappen -- zelfde
      topics/ACL's/RDP-naam, alleen het fysieke eindpunt wisselt.
      (`PLAN.md` sectie 10, fase 1; sectie 13, bullet "STACKIT
      GA-timing".)
- [ ] **Volledige testronde (fase 5) herhalen vlak vóór DADD**, niet
      vertrouwen op de eerdere validatie -- sindsdien zijn er meerdere
      functionele wijzigingen bijgekomen (alle 3 klassen per run,
      dynamische topics, variatie-uitbreidingen). (`PLAN.md` sectie 10,
      fase 5.)

## Zou goed zijn vóór DADD

- [ ] **Negative ACL-test uitvoeren** (testplan-punt 5, nog niet gedaan):
      bewust een "verkeerde" client-username op een andere klasse se topic
      laten publiceren en bevestigen dat de broker dit weigert -- laat de
      governance-garantie zien, niet alleen de happy path. (`PLAN.md`
      sectie 12, punt 5.)
- [ ] **Koude-starttijd meten**: tijd van `docker run` tot alle 3 RDP's
      "Up", om te checken of dat ruim binnen de gewenste ~5 minuten voor
      het podium past; anders de cloud-brokers vooraf al "warm" laten
      draaien. (`PLAN.md` sectie 12, punt 7.)
- [ ] **Twee punten expliciet benoemen in de talk zelf** (geen code-werk):
      dat Azure hier fysiek in de EU staat maar organisatorisch een
      Amerikaanse hyperscaler is (relevant gezien slide 2's CLOUD
      Act-punt), en dat de cloud-broker-services bewust in public clusters
      staan i.p.v. private/VPC-gepeerd. (`PLAN.md` sectie 13, bullets
      "Azure = Amerikaanse hyperscaler" en "Public clusters".)

## Kan na DADD (bewuste scope-keuzes voor nu)

- [ ] Automatische provisioning van alle 4 brokers in één commando
      (Terraform/Ansible i.p.v. losse scripts). **Deels in uitvoering:**
      de 3 cloud-services gaan nu via Terraform (zie bovenaan dit
      bestand, "Blokkerend") -- de lokale broker (Docker + SEMP-config)
      zit daar nog niet in. (`PLAN.md` sectie 13, bullet "Geen
      automatische provisioning".)
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
