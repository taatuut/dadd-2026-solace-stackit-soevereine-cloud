# Demo-apps: toelichting en draaiboek

Zie `../demo-apps/README.md` voor het overzicht van de drie tools. Dit
document geeft het voorgestelde draaiboek voor de live demo, gespiegeld aan
slide 23 ("Data that can't cross the border") van de sovereign-cloud-deck.

## Voorgesteld draaiboek (aansluitend op de presentatie)

1. **Publiek**: `demo-apps/stm-public/publish-public.sh` -- laat in de
   Solace Cloud "Try Me!"-tab van de **AWS**-broker de binnenkomende
   dagprijzen zien. Boodschap: onschuldige data mag gewoon naar de
   hyperscaler.
2. **Niet-persoonlijk EU**: `demo-apps/python-eu-nonpersonal/publisher.py`
   -- laat in de "Try Me!"-tab van de **Azure**-broker de geaggregeerde
   netbelasting zien. Boodschap: EU-gebonden, maar niet privacygevoelig
   genoeg voor de zwaarste route.
3. **Gevoelige PII**: `demo-apps/sdkperf-pii/publish-pii.sh` -- laat zien dat
   deze berichten **alleen** op de **STACKIT**-broker verschijnen, en
   expliciet *niet* op AWS of Azure (open beide "Try Me!"-tabs naast elkaar
   zodat het publiek het verschil letterlijk ziet, net als in slide 23 van de
   deck: "watch it stay" vs. "share the safe part").
4. Optioneel, als er tijd is: laat in Broker Manager van de lokale broker de
   3 REST Delivery Points en hun queue message-counts zien, als "achter de
schermen"-bewijs dat
   dit door topic-routering komt, niet door drie losse handmatige acties.

## Timing

Punt 1 en 2 kunnen in één aén adem (± 30-45 sec elk); punt 3 is het "aha"-
moment en verdient de meeste stilte/nadruk. Totaal ruim binnen de 4 minuten
die de presentatie zelf voor de live demo reserveert (zie de sprekersnotities
bij slide 23 van de deck).

## Fallback

Zoals de presentatie zelf ook aanraadt voor de eigen demo: neem vooraf een
schermopname van een geslaagde run op als fallback voor het geval de
conferentiewifi/hardware niet meewerkt. Zie `PLAN.md`, sectie
"Draaiboek voor de live demo".
