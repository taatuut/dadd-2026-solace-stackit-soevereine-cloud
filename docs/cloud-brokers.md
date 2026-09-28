# Cloud platform brokers: opzet

Zie ook de drie submappen in `../cloud-setup/` voor de concrete,
provider-specifieke stappen. Dit document geeft de bredere toelichting en
het STACKIT-afwegingspunt.

## Waarom drie aparte HA-services, en waarom deze indeling?

De drie cloud-brokers corresponderen 1-op-1 met de drie dataklassen uit de
opdracht:

1. **AWS US East** -- publieke data. Bewust op een Amerikaanse hyperscaler:
   dit laat zien dat sovereignty geen "alles naar Europa"-verhaal is, maar
   een **classificatievraagstuk** -- niet-gevoelige data mag prima op de
   hyperscaler blijven (vgl. slide 8 van de presentatie: "You won't pick one
   cloud. You'll run two.").
2. **Azure West Europe (Nederland)** -- niet-persoonlijke data die wel
   EU-gebonden moet blijven, maar niet de zwaarste soevereiniteitseisen
   heeft. Azure "West Europe" is fysiek Nederland, dus dit voldoet aan de
   eis, ook al is Microsoft zelf een Amerikaanse hyperscaler (relevant
   gezien slide 2 van de presentatie over het CLOUD Act-risico -- zie
   "Wat ontbreekt of kan beter" hieronder).
3. **STACKIT eu01 (Duitsland)** -- gevoelige PII, op een soeverein, Europees
   platform zonder Amerikaanse moederonderneming.

## STACKIT: uitgangspunt en interim-opzet

Uitgangspunt voor dit plan: STACKIT wordt **komende week algemeen
beschikbaar (GA)** in Solace Cloud, met dezelfde self-service
deployment-ervaring als AWS, Azure en GCP -- gewoon te kiezen als
datacenter, geen aparte Controlled-Availability/BYOK-procedure meer. Zie
`../cloud-setup/stackit-eu01/README.md` voor de (eenvoudige) aanmaakstappen
zodra dat zo is.

**Tot het zover is**, gebruikt de demo een tijdelijke stand-in: een Solace
Cloud HA-service op **GCP, regio europe-west1 (België)** -- inmiddels
aangemaakt als `ez-dadd-2026-STACKIT-gke-gcp-europe-west1-b` (status:
Running), zie `../cloud-setup/gcp-europe-west1-interim/README.md` voor de
details. Functioneel identiek voor de demo (zelfde topics, ACL-profiel en
bridge-naam `bridge-to-stackit`); alleen de fysieke locatie/provider wijkt
tijdelijk af van het uiteindelijke soevereine doel. Zodra STACKIT GA is, is
de overstap een kwestie van de echte service aanmaken, de `STACKIT_*`-
variabelen in `local-broker/.env` bij te werken en
`configure-local-broker.sh` opnieuw te draaien -- geen wijziging aan topics,
ACL's of bridge-configuratie nodig.

**Restrisico**: GA-planningen kunnen schuiven. Zolang STACKIT niet
daadwerkelijk beschikbaar is op het moment van de repetitie/DADD zelf, blijft
de GCP-interim-opzet de facto de sovereign-node in de demo -- benoem dat in
dat geval eerlijk (GCP is zelf een Amerikaanse hyperscaler, dus dan toon je
de routeringslogica correct, maar niet de volledige soevereiniteitsclaim).
Plan daarom een korte check vlak voór de repetitieweek (zie fasering in
`PLAN.md`) om te bevestigen of STACKIT inderdaad al zichtbaar is als
datacenter-optie.

## Provisioning: console vs. API

Voor een eenmalige, goed te plannen demo-opzet is de **Solace Cloud console**
de eenvoudigste weg (minder foutgevoelig, visuele bevestiging van HA-status).
`../cloud-setup/solace-cloud-api/create-service.sh` is een optioneel
alternatief voor wie de opzet wil kunnen herhalen/scripten (bijv. na een
oefensessie de services afbreken en later opnieuw exact zo aanmaken).

## Wat de AWS-, Azure- en GCP-interim-opzet ons hebben geleerd (fase 3 compleet)

Alle drie de cloud-broker services zijn nu aangemaakt: AWS US East
(`ez-dadd-2026-eks-us-east-1a`), Azure West Europe
(`ez-dadd-2026-aks-westeurope`) en de STACKIT/GCP-interim-stand-in
(`ez-dadd-2026-STACKIT-gke-gcp-europe-west1-b`, service-ID `0kc8gh43pg3`,
regio-code `gke-gcp-europe-west1-b`). Screenshots van elke stap staan in
[`../screenshots/AWS/`](../screenshots/AWS/),
[`../screenshots/Azure/`](../screenshots/Azure/) en
[`../screenshots/STACKIT-of-GCP-interim/`](../screenshots/STACKIT-of-GCP-interim/).

Concrete correcties/aanvullingen op basis daarvan:

- **Region-codes in Solace Cloud zijn geen kale AWS-regio's.** De console
  toont regio's als `eks-us-east-1a` (niet `us-east-1`) -- Solace Cloud
  draait blijkbaar op EKS-onderliggende infrastructuur. Zoek de exacte
  waarde altijd op in de Region-dropdown of via
  `GET .../missionControl/datacenters`, neem 'm niet zomaar over uit dit
  document.
- **Message VPN-naam wordt auto-gegenereerd uit de servicenaam**, afgekapt op
  **26 tekens** als die langer is (AWS: `ez-dadd-2026-eks-us-east-1a` ->
  VPN `ez-dadd-2026-eks-us-east-1`; Azure: `ez-dadd-2026-aks-westeurope` ->
  VPN `ez-dadd-2026-aks-westeurop`), tenzij je die handmatig overschrijft
  onder "Advanced Connection Options". Dit hoeft dus **niet** voor elke
  broker "enewable" te heten -- de lokale broker heeft zijn eigen VPN-naam
  (`enewable`, door onszelf gekozen) en elke cloud-service heeft zijn eigen
  (auto-gegenereerde of handmatig gekozen) naam. Een bridge verbindt twee
  VPN's met verschillende namen probleemloos.
- **Naamgevingsconventie**: AWS en Azure volgen `ez-dadd-2026-<provider>-
  <regio>`. Voor de STACKIT/GCP-interim-service is bewust afgeweken naar
  `ez-dadd-2026-STACKIT-gke-gcp-europe-west1-b` -- de expliciete `STACKIT`
  in de naam maakt in de Cluster Manager-lijst en op screenshots direct
  duidelijk dat dít knooppunt de (tijdelijke) sovereign-bestemming is, wat
  waardevoller bleek dan strikte naamconsistentie tussen de drie services.
- **Message VPN-namen worden ook naar kleine letters omgezet.** De
  servicenaam `ez-dadd-2026-STACKIT-gke-gcp-europe-west1-b` (met
  hoofdletters `STACKIT`) leverde VPN-naam `ez-dadd-2026-stackit-gke-g` op
  -- exact 26 tekens, en volledig lowercase. Dit was bij AWS/Azure niet
  zichtbaar omdat die servicenamen al lowercase waren; ga er dus van uit dat
  Solace Cloud VPN-namen altijd lowercased, ook als de servicenaam
  hoofdletters bevat.
- **Service class**: Enterprise, 250 connecties, 50 GB message spool,
  High Availability (HA) Group (3 brokers: active/standby/monitoring),
  broker-release 10.26 -- gebruik dezelfde class voor Azure en
  STACKIT/GCP-interim voor consistentie, tenzij er een reden is om af te
  wijken.
- **Connect-tab (exacte host:poort en client-username voor de bridge) is nog
  niet vastgelegd voor AWS en Azure, en voor GCP-interim staat alleen de
  SMF-hostnaam uit het Status-scherm vast** -- dat is nu de eerstvolgende
  sub-stap voor alle drie services, zie `../local-broker/.env.example`.

## Concrete gegevens per service

| Service | Service-ID | Regio-code | Message VPN | SMF-hostname |
|---|---|---|---|---|
| AWS US East | (zie screenshots) | `eks-us-east-1a` | `ez-dadd-2026-eks-us-east-1` | `mr-connection-07w9t1ah76x.messaging.solace.cloud` |
| Azure West Europe | `9vxfvj278k6` | `aks-westeurope` | `ez-dadd-2026-aks-westeurop` | `mr-connection-1uv2i5bgjkm.messaging.solace.cloud` |
| STACKIT/GCP-interim | `0kc8gh43pg3` | `gke-gcp-europe-west1-b` | `ez-dadd-2026-stackit-gke-g` | `mr-connection-gp982rqw5dk.messaging.solace.cloud` |

Alle drie: Enterprise, 250 connecties, 50 GB message spool, HA Group,
broker-release 10.26 (GCP-interim: 10.26.0.8894-14), aangemaakt door Emil
Zegers op 28/09/2026.

## Netwerktoegang: public clusters (bewuste keuze voor deze demo)

Alle cloud-broker services worden aangemaakt in **public clusters** --
bereikbaar over het publieke internet, TLS + gebruikersnaam/wachtwoord als
enige beveiligingslaag op de bridge-verbinding. Dat is een bewuste keuze
voor het gemak en de snelheid van deze demo-opzet (geen VPN/peering nodig
vanaf een laptop op een podium).

**In een real-life inrichting** zouden dit private clusters zijn, met
verdergaande netwerkbeveiliging tussen de lokale broker en elke cloud-broker
-- bijvoorbeeld VPC peering, AWS/Azure PrivateLink of het STACKIT-equivalent
-- zodat het verkeer nooit het publieke internet op hoeft. Zie `PLAN.md`,
sectie 13, voor dit punt als expliciete "wat kan beter"-post. **Benoem deze
vereenvoudiging ook gewoon eerlijk in de presentatie/demo zelf**, zoals de
deck ook zelf transparant is over wat "direction/roadmap" is versus wat er
al werkt.

## Credentials

- Elke service krijgt een eigen client-username voor de inkomende
  bridge-verbinding, met een ACL-profiel dat het verkeer tot de juiste
  topic-subtree beperkt (zie per submap in `../cloud-setup/`).
- Bewaar client-secrets nooit in de repo; gebruik `.env`-bestanden (zie
  `.gitignore`) of, voor een teamsetting, een secrets-manager. Hetzelfde
  geldt voor het Solace Cloud API-token (`token-dadd-2026.txt`, ook
  gitignored).
