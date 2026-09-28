# Python-script -- niet-persoonlijke EU-data (Azure)

Publiceert geaggregeerde netbelasting per postcodegebied naar de lokale
broker op `enewable/eu/ops/grid/load`, met de
[Solace PubSub+ Python API](https://docs.solace.com/API/API-Developer-Guide-Python/).

## Installatie

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

## Gebruik

```bash
cp .env.example .env   # of laat leeg en hergebruik ../../local-broker/.env
python publisher.py --count 20 --interval 1
```

Verifieer op de Azure-broker (Solace Cloud console, tab "Try Me!") dat de
berichten hier binnenkomen op `enewable/eu/ops/>`, en nergens anders.

## Waarom een los script i.p.v. stm/SDKPerf?

Dit demonstreert de derde manier van dataproductie uit de opdracht (naast
`stm` en SDKPerf): een eigen applicatie die de Solace-taal-API rechtstreeks
gebruikt, zoals een echt Enewable-backend-systeem dat zou doen. Qua
governance is dit script bewust identiek behandeld aan de andere twee: een
eigen, met een ACL-profiel beperkte client-username die alleen op
`enewable/eu/ops/>` mag publiceren.
