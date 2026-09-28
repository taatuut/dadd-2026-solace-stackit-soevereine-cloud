# Demo-apps (databronnen)

Drie losse publicatie-tools, elk voor één dataklasse, die allemaal naar de
**lokale** broker publiceren (nooit rechtstreeks naar een cloud-broker -- dat
gaat via REST Delivery Points, zie `../local-broker/`):

| Tool                                   | Map                        | Dataklasse                    | Topic-subtree            | RDP naar |
|-----------------------------------------|----------------------------|--------------------------------|---------------------------|-------------|
| Solace Try-Me CLI (`stm`)                | `stm-public/`               | Publiek (energieprijzen, weer) | `enewable/public/>`       | AWS (`rdp-aws`)         |
| Python-script (Solace Python API)        | `python-eu-nonpersonal/`    | Niet-persoonlijk, EU           | `enewable/eu/ops/>`       | Azure (`rdp-azure`)       |
| SDKPerf                                  | `sdkperf-pii/`              | Gevoelige PII                  | `enewable/eu/pii/>`       | STACKIT (`rdp-stackit`)     |

Elke tool gebruikt een eigen, met een ACL-profiel beperkte client-username
(aangemaakt door `../local-broker/semp/configure-local-broker.sh`), zodat
bijvoorbeeld de PII-publisher fysiek niet kan publiceren op het publieke
topic, en omgekeerd. Dat is de "governed sharing"-gedachte uit de presentatie
toegepast op de publicatiekant, niet alleen op de exportkant (RDP).

Zie `../docs/demo-apps.md` voor de volledige toelichting en het voorgestelde
draaiboek voor de live demo.
