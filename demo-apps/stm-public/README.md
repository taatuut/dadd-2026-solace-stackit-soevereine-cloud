# stm -- publieke data (AWS)

Gebruikt [Solace Try-Me CLI](https://github.com/SolaceLabs/solace-tryme-cli)
(`stm`) om publieke Enewable-data te publiceren: day-ahead energieprijzen en
publieke weerdata voor opwekvoorspelling. Geen persoonsgegevens.

## Installatie

```bash
npm install -g solace-tryme-cli
stm --version
```

## Gebruik

```bash
./publish-public.sh
```

Of handmatig, één bericht:

```bash
stm send \
  --url ws://localhost:8008 \
  --vpn enewable \
  --username pub-public --password "$PUB_PUBLIC_PASSWORD" \
  --topic enewable/public/market/price \
  --file sample-payload.json \
  --delivery-mode DIRECT
```

Let op `--delivery-mode DIRECT`: `stm send` publiceert standaard
PERSISTENT (guaranteed), wat de lokale broker afwijst ("Sending
guaranteed message is not allowed by router for this client") omdat het
`default` client-profile bewust `allowGuaranteedMsgSendEnabled: false`
heeft -- deze demo is expliciet op DIRECT-publiceren + automatische
queue-promotion gebouwd (zie `PLAN.md` sectie 13, punt 22).

Verifieer op de AWS-broker (Solace Cloud console van de AWS-service, tab
"Try Me!") dat je hier de berichten ziet binnenkomen op
`enewable/public/>`, en dat er **niets** binnenkomt op de Azure- of
STACKIT-broker.
