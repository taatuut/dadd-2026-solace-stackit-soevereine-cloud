# Azure West Europe (Nederland) -- Solace Cloud HA broker (niet-persoonlijke EU-data)

Rol: eindpunt voor **niet-persoonlijke, EU-gebonden** operationele data (bijv.
geaggregeerde netbelasting per postcodegebied, geanonimiseerde
verbruikstrends). Deze data mag niet buiten de EU, maar is niet
privacygevoelig genoeg om de sovereign-only (STACKIT) route te vereisen --
een bewuste middenklasse tussen "publiek" en "PII", die in de presentatie
overeenkomt met het "governed sharing / allowlist"-idee (alleen geminimaliseerde
data mag oversteken).

> Let op: Azure's regio "West Europe" staat fysiek in Nederland
> (Amsterdam-datacenters), dus dit voldoet aan "moet in Europa blijven".
> Voor een striktere sovereignty-garantie (geen Amerikaanse hyperscaler,
> ook al staat de data fysiek in de EU) zou je in een latere iteratie ook
> deze klasse naar STACKIT of een andere Europese aanbieder kunnen
> verplaatsen -- zie `../../docs/cloud-brokers.md`, sectie "Wat ontbreekt of
> kan beter".

## Status: aangemaakt

Service **`ez-dadd-2026-aks-westeurope`** is aangemaakt (28/09/2026).
Screenshots van elke stap staan in
[`../../screenshots/Azure/`](../../screenshots/Azure/).

| Veld | Waarde |
|---|---|
| Cloud / regio | Azure, `aks-westeurope` (regio-code is AKS-gebaseerd, net als AWS' `eks-us-east-1a`) |
| Service class | Enterprise, 250 connecties, 50 GB message spool |
| High Availability | HA Group (active/standby/monitoring, 3 brokers) |
| Broker release | 10.26.0.8894-14 |
| Cluster | **Public** (zie `../../docs/cloud-brokers.md`, "Netwerktoegang") |
| Message VPN | `ez-dadd-2026-aks-westeurop` (auto-gegenereerd, afgekapt op 26 tekens -- zie hieronder) |
| SMF-hostname | `mr-connection-1uv2i5bgjkm.messaging.solace.cloud` (poort nog te bevestigen op de Connect-tab, standaard 55443/TLS) |
| Service ID | `9vxfvj278k6` |

**Geleerd van AWS + Azure samen**: een auto-gegenereerde Message VPN-naam
wordt afgekapt op **26 tekens** als de servicenaam langer is (AWS:
`ez-dadd-2026-eks-us-east-1a` -> VPN `ez-dadd-2026-eks-us-east-1`; Azure:
`ez-dadd-2026-aks-westeurope` -> VPN `ez-dadd-2026-aks-westeurop`). Puur
cosmetisch (een RDP werkt prima met deze naam), maar goed om te weten als
je een VPN-naam wilt die exact de servicenaam volgt: houd 'm dan onder de
26 tekens, of zet de VPN-naam handmatig onder "Advanced Connection Options".

## Status: publish-toegang ingericht (gebruikt door de RDP)

✅ `enewable-local-bridge` + ACL-profiel `acl-enewable-local-bridge`
(publish-only op `enewable/eu/ops/>`) zijn aangemaakt via
`../solace-cloud-api/configure-remote-bridge-users.sh` (SEMP-admin-username
`mission-control-manager`). Credentials staan in `../../local-broker/.env` --
deze worden nu gebruikt door de REST Delivery Point's REST-consumer
(`../../local-broker/semp/configure-rdp-export.sh`), niet meer door een
bridge.

## Nog te doen voor deze service

1. ~~**Connect-tab**: exacte SMF-poort en REST-poort bevestigen; REST-
   messaging aanzetten.~~ ✅ Bevestigd: REST-poort is 9443/TLS (zelfde
   hostname als SMF), REST-messaging stond al aan. Onafhankelijk bewezen
   door een geslaagde end-to-end test: 20 Direct-berichten aangekomen op
   Azure "Try Me!" op `enewable/eu/ops/grid/load`, niets op AWS (zie
   `../../docs/lokale-broker.md`, "Eindresultaat").
2. ~~Client-username + ACL-profiel aanmaken~~ ✅ gedaan, zie "Status:
   publish-toegang ingericht" hierboven.
3. ~~Host, VPN-naam en credentials in `../../local-broker/.env` invullen~~ ✅
   gedaan (VPN-naam `ez-dadd-2026-aks-westeurop` en credentials staan er al
   in onder de `AZURE_*`-variabelen).

**Deze service is klaar en volledig getest -- geen verdere actie nodig.**
