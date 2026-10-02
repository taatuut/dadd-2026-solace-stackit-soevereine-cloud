# Presentatienotities - expliciet te benoemen in de talk zelf

Dit zijn geen code- of configuratiepunten: dit zijn twee bewuste
architectuurkeuzes in deze demo die in de presentatie zelf hardop benoemd
moeten worden, anders blijven ze onzichtbare aannames. Zie `PLAN.md`
sectie 13 voor de volledige achtergrond; dit bestand is het beknopte,
spreektekst-klare geheugensteuntje.

## 1. Azure staat fysiek in de EU, maar is organisatorisch een Amerikaanse hyperscaler

De Azure-broker in deze demo draait in West Europe (Nederland) - data
blijft dus fysiek binnen de EU. Maar Microsoft is en blijft een
Amerikaans bedrijf, onderhevig aan de CLOUD Act. Dat is relevant en
*moet* benoemd worden, juist omdat slide 2 van de presentatie zelf het
CLOUD Act-risico bij Amerikaanse hyperscalers aankaart: wie hier niet
expliciet bij stilstaat, laat het publiek zelf de (onjuiste) conclusie
trekken dat "data in de EU" vanzelf hetzelfde is als "soeverein". Het punt
van de demo is juist dat classificatie (niet-persoonlijk vs. gevoelige
PII) bepaalt welke broker een gegeven mag bereiken - Azure is hier bewust
toegestaan voor niet-persoonlijke EU-data, STACKIT is voorbehouden aan
echt gevoelige PII.

## 2. De cloud-broker-services staan in public clusters, niet private/VPC-gepeerd

Alle 3 Solace Cloud-services (AWS, Azure, STACKIT) draaien in deze demo
op public clusters, bereikbaar over het publieke internet (met TLS +
credentials), niet in een private cluster met VPC-peering of PrivateLink.
Dit is een bewuste vereenvoudiging om de demo snel en overal (ook vanaf
een conferentie-wifi) op te kunnen zetten - geen VPN's, geen
netwerk-peering-overhead. In een echte productie-inrichting zou je dit
typisch wel privaat/gepeerd doen. Benoem dit expliciet zodat het publiek
het niet aanziet voor de aanbevolen praktijk.
