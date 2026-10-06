# Cloud platform brokers: opzet

Zie ook de drie submappen in `../cloud-setup/` voor de concrete,
provider-specifieke stappen. Dit document geeft de bredere toelichting en
het STACKIT-afwegingspunt.

## Waarom drie aparte cloud-services, en waarom deze indeling?

De drie cloud-brokers corresponderen 1-op-1 met de drie dataklassen uit de
opdracht:

1. **AWS US East** - publieke data. Bewust op een Amerikaanse hyperscaler:
   dit laat zien dat sovereignty geen "alles naar Europa"-verhaal is, maar
   een **classificatievraagstuk** - niet-gevoelige data mag prima op de
   hyperscaler blijven (vgl. slide 8 van de presentatie: "You won't pick one
   cloud. You'll run two.").
2. **Azure West Europe (Nederland)** - niet-persoonlijke data die wel
   EU-gebonden moet blijven, maar niet de zwaarste soevereiniteitseisen
   heeft. Azure "West Europe" is fysiek Nederland, dus dit voldoet aan de
   eis, ook al is Microsoft zelf een Amerikaanse hyperscaler (relevant
   gezien slide 2 van de presentatie over het CLOUD Act-risico - zie
   "Wat ontbreekt of kan beter" hieronder).
3. **STACKIT eu01 (Duitsland)** - gevoelige PII, op een soeverein, Europees
   platform zonder Amerikaanse moederonderneming.

## STACKIT: publieke `SolacePublic`-regio in Solace Cloud

STACKIT heeft een eigen, echte publieke regio in Solace Cloud:
datacenter-id `ske-eu01` (`datacenterType SolacePublic`, provider `ske`
= "StackIT Kubernetes Engine", regio "Germany"), met dezelfde
self-service deployment-ervaring als AWS en Azure - gewoon te kiezen
als datacenter bij het aanmaken van de service, geen aparte
Controlled-Availability/BYOK-procedure. **Gebruik uitsluitend dit
datacenter.** Dezelfde Solace Cloud-organisatie bevat ook een
`stackitdemo-stackit-eu01-production`-datacenter (`datacenterType
SolaceDedicated`, provider `k8s`) - een *dedicated*, aan één
organisatie gebonden cluster dat in de Solace Cloud console onder het
generieke "Private Cloud"-icoon staat in plaats van het
STACKIT-icoon, ook al draait het fysiek ook op STACKIT-infrastructuur.
Dit per ongeluk gekozen leverde eerder een verkeerd geregionaliseerde
service op (zie `../PLAN.md`, sectie 13, punt 58) - controleer bij elke
nieuwe service altijd `datacenterType` via `GET
{stackit_org_base_url}api/v2/missionControl/datacenters` voordat je een
datacenter-id overneemt. Zie `../cloud-setup/terraform/README.md` voor
de Terraform-opzet die de 3 services aanmaakt, en
`../cloud-setup/stackit-eu01/README.md` voor de STACKIT-specifieke
details.

## Provisioning: console vs. API

Voor een eenmalige, goed te plannen demo-opzet is de **Solace Cloud console**
de eenvoudigste weg (minder foutgevoelig, visuele bevestiging van de servicestatus).
`../cloud-setup/solace-cloud-api/create-service.sh` is een optioneel
alternatief voor wie de opzet wil kunnen herhalen/scripten (bijv. na een
oefensessie de services afbreken en later opnieuw exact zo aanmaken).

**Twee verschillende Solace Cloud API's, niet één** - dit is een makkelijk te
verwarren punt:

1. **Mission Control API** (`api.solace.cloud`, `Bearer` met het
   `token-dadd-2026.txt`-token) - beheert de **services zelf**
   (aanmaken/verwijderen/schalen). Gebruikt door `create-service.sh`.
2. **SEMP v2 Config API van elke broker afzonderlijk** (`<service>:943`,
   Basic Auth met de **SEMP-admin-username/password van die specifieke
   broker** - niet het Mission Control-token, en niet `solace-cloud-client`)
   - beheert **objecten binnen** die broker: Message VPN's,
   client-usernames, ACL-profielen, queues, REST Delivery Points. Gebruikt door
   `../local-broker/semp/configure-local-broker.sh` en
   `../local-broker/semp/configure-rdp-export.sh` (lokaal) en
   `../cloud-setup/solace-cloud-api/configure-remote-bridge-users.sh`
   (op afstand, voor de 3 cloud-brokers - deze naam dekt niet de huidige
   functie: het script maakt de publish-client-username die door de RDP's
   REST-consumer wordt gebruikt, niet door een bridge). De
   SEMP-admin-username op de Connect-tab van elke Solace Cloud-service heet
   `mission-control-manager` (per service een eigen wachtwoord), op
   `https://<smf-hostnaam>:943`.

**Netwerktoegang vanuit deze sessie is getest en geblokkeerd voor beide.**
Zowel `api.solace.cloud` als de drie broker-hostnamen
(`mr-connection-*.messaging.solace.cloud`) zijn vanuit zowel de
cloud-container als de sandbox-VM op je Mac onbereikbaar: een
organisatie-brede proxy-allowlist geeft `403 blocked-by-allowlist`
(sandbox-VM) resp. sluit de TLS-verbinding (cloud-container). Concreet
betekent dit dat elk script dat `api.solace.cloud` of een broker-SEMP-host
aanroept, **door jou zelf gedraaid moet worden** in je eigen, gewone
terminal (dezelfde waarin `git push` en `docker-run.sh` al werkten) - niet
door de assistent.

## Lessen voor handmatige aanmaak via de console

Relevant als je een service handmatig via de Solace Cloud console aanmaakt
(i.p.v. via Terraform, zie `../cloud-setup/terraform/README.md`):

- **Region-codes in Solace Cloud zijn geen kale AWS/Azure-regio's.** De
  console toont regio's als `eks-us-east-1a` (niet `us-east-1`) of
  `aks-westeurope` - zoek de exacte waarde altijd op in de
  Region-dropdown of via `GET .../missionControl/datacenters`, neem 'm
  niet zomaar over uit dit document.
- **Message VPN-naam wordt, tenzij je 'm handmatig zet, auto-gegenereerd
  uit de servicenaam en afgekapt op 26 tekens** (en altijd lowercased, ook
  als de servicenaam hoofdletters bevat). Zet de VPN-naam daarom handmatig
  onder "Advanced Connection Options" als je een voorspelbare naam wilt -
  de Terraform-opzet doet dit al expliciet (`enewable` voor alle drie
  services). Een REST Delivery Point post naar een gewoon REST-endpoint
  (host:poort), dus VPN's met verschillende namen verbinden probleemloos.
- **Connect-tab geeft het exacte REST host:poort voor de RDP** (naast de
  SMF-hostnaam) - standaard dezelfde hostname als SMF op poort 9443
  (Solace Cloud's standaard secure-REST-poort), bevestig dit per service.

Actuele host-, VPN- en service-gegevens per broker staan in
`../local-broker/.env` en in de Terraform-output
(`terraform output -json <service>`), niet hieronder vastgelegd - die
veranderen bij elke herinrichting van de services.

## Netwerktoegang: public clusters (bewuste keuze voor deze demo)

Alle cloud-broker services worden aangemaakt in **public clusters** -
bereikbaar over het publieke internet, TLS + gebruikersnaam/wachtwoord als
enige beveiligingslaag op de RDP-verbinding. Dat is een bewuste keuze
voor het gemak en de snelheid van deze demo-opzet (geen VPN/peering nodig
vanaf een laptop op een podium).

**In een real-life inrichting** zouden dit private clusters zijn, met
verdergaande netwerkbeveiliging tussen de lokale broker en elke cloud-broker
- bijvoorbeeld VPC peering, AWS/Azure PrivateLink of het STACKIT-equivalent
- zodat het verkeer nooit het publieke internet op hoeft. Zie `PLAN.md`,
sectie 13, voor dit punt als expliciete "wat kan beter"-post. **Benoem deze
vereenvoudiging ook gewoon eerlijk in de presentatie/demo zelf**, zoals de
deck ook zelf transparant is over wat "direction/roadmap" is versus wat er
al werkt.

## Credentials

- Elke service krijgt een eigen, **nieuw aangemaakte** client-username voor
  de inkomende verbinding vanaf de lokale broker's REST Delivery Point:
  `enewable-local-bridge` op alle drie de
  cloud-services, elk met een eigen, al gegenereerd wachtwoord in
  `../local-broker/.env` (niet gecommit). Aanmaken kan handmatig (Manage >
  Client Usernames, zie per submap in `../cloud-setup/`) of via
  `../cloud-setup/solace-cloud-api/configure-remote-bridge-users.sh`, zodra
  je de SEMP-admin-username/password per broker in `.env` hebt ingevuld
  (Connect-tab van de service) - zie hierboven waarom dit een ander
  token/andere credentials zijn dan het Mission Control-token.
- **Gebruik hiervoor niet de standaard `solace-cloud-client`-username** die
  Solace Cloud standaard aanmaakt. Die identiteit wordt door de "Try Me!"-tab
  van elke service gebruikt om tijdens de live demo de binnenkomende
  berichten te tonen (zie `docs/demo-apps.md`), en heeft van zichzelf een
  ruim ACL-profiel. Een ACL-restrictie op `solace-cloud-client` zou dus
  zowel de RDP's REST-consumer als de "Try Me!"-subscriptie raken - en het hele punt van
  de demo is juist dat de scheiding tussen dataklassen door de ACL wordt
  *afgedwongen*, niet dat hij toevallig lijkt te werken omdat er verder
  niets anders op die topic-subtree publiceert.
- Bewaar client-secrets nooit in de repo; gebruik `.env`-bestanden (zie
  `.gitignore`) of, voor een teamsetting, een secrets-manager. Hetzelfde
  geldt voor het Solace Cloud API-token (`token-dadd-2026.txt`, ook
  gitignored).
