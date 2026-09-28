#!/usr/bin/env python3
"""Publishes Enewable demo data to the local broker using the Solace
PubSub+ Python API.

By default this publishes ALL 3 data classes in one run -- public,
non-personal EU, and sensitive PII -- one after another, each with its OWN
scoped client-username (pub-public/pub-eu-ops/pub-eu-pii) and its own
topic. This is deliberate: it demonstrates that the destination
cloud-broker (AWS/Azure/STACKIT) is decided purely by TOPIC, via the
RDP-export queues (see local-broker/semp/configure-rdp-export.sh), never by
which TOOL published the message -- this one Python script lands a message
on Azure the same way it lands the next one on STACKIT, just by switching
topic + credential. Use --class to restrict to a single class (e.g. for
isolated testing). See PLAN.md section 13 for the reasoning behind this
change (Emil's review of the original, one-class-per-app demo).

Each class opens its OWN MessagingService connection (a Solace client
identity is tied to one client-username at a time) -- not one shared
connection reused for all 3, so the ACL enforcement at the source stays
real and per-class, exactly like the other 2 demo-apps.

Usage:
    pip install -r requirements.txt
    python publisher.py [--class public|eu-ops|eu-pii] [--count 20] [--interval 1.0]
"""
from __future__ import annotations

import argparse
import json
import os
import random
import sys
import time
from pathlib import Path

from dotenv import load_dotenv

from solace.messaging.messaging_service import MessagingService
from solace.messaging.config.solace_properties import (
    authentication_properties,
    service_properties,
    transport_layer_properties,
)
from solace.messaging.resources.topic import Topic

POSTCODE_AREAS = ["1000-NL", "3500-NL", "5600-NL", "9700-NL"]
CUSTOMER_IDS = ["ENW-NL-000482", "ENW-NL-000917", "ENW-NL-002203"]


def load_config() -> dict:
    here = Path(__file__).resolve().parent
    # Prefer this app's own .env, fall back to the shared local-broker/.env
    load_dotenv(here / ".env")
    load_dotenv(here.parent.parent / "local-broker" / ".env", override=False)

    return {
        "host": os.environ.get("LOCAL_SMF_HOST", "localhost:55554"),
        "vpn": os.environ.get("LOCAL_MSG_VPN", "enewable"),
    }


def make_public_message() -> dict:
    return {
        "source": "enewable-market-feed",
        "type": "day-ahead-price",
        "market": "NL",
        "currency": "EUR",
        "pricePerMWh": round(random.uniform(40.0, 140.0), 2),
        "classification": "public",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }


def make_eu_ops_message() -> dict:
    return {
        "source": "enewable-grid-telemetry",
        "type": "grid-load-aggregate",
        "postcodeArea": random.choice(POSTCODE_AREAS),
        "loadKw": round(random.uniform(400.0, 1200.0), 1),
        "sampleSizeMeters": random.randint(50, 500),
        "classification": "non-personal-eu",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }


def make_eu_pii_message() -> dict:
    # Deliberately fictitious, synthesized customer data -- never use real
    # personal data in a demo (see demo-apps/sdkperf-pii/README.md).
    return {
        "source": "enewable-smart-meter",
        "type": "meter-reading",
        "customerId": random.choice(CUSTOMER_IDS),
        "meterId": "SM-9931-77",
        "kwh": round(random.uniform(0.5, 6.0), 3),
        "classification": "PII",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }


# (topic, env var prefix, message generator) per class -- kept in one place
# so the 3 demo-apps stay easy to compare (see stm-public/publish-public.sh
# and sdkperf-pii/publish-pii.sh, which mirror this same structure in bash).
CLASSES = {
    "public": ("enewable/public/market/price", "PUB_PUBLIC", make_public_message),
    "eu-ops": ("enewable/eu/ops/grid/load", "PUB_EU_OPS", make_eu_ops_message),
    "eu-pii": ("enewable/eu/pii/meter/reading", "PUB_EU_PII", make_eu_pii_message),
}


def publish_class(class_name: str, config: dict, count: int, interval: float) -> None:
    topic_str, env_prefix, make_message = CLASSES[class_name]
    username = os.environ.get(f"{env_prefix}_USER")
    password = os.environ.get(f"{env_prefix}_PASSWORD")
    if not password:
        raise SystemExit(
            f"Set {env_prefix}_PASSWORD (see local-broker/.env) -- "
            f"needed to publish the '{class_name}' class."
        )

    print(f"-- {class_name}: {topic_str} (as {username}) --")

    messaging_service = (
        MessagingService.builder()
        .from_properties(
            {
                transport_layer_properties.HOST: config["host"],
                service_properties.VPN_NAME: config["vpn"],
                authentication_properties.SCHEME_BASIC_USER_NAME: username,
                authentication_properties.SCHEME_BASIC_PASSWORD: password,
            }
        )
        .build()
    )
    messaging_service.connect()

    publisher = messaging_service.create_direct_message_publisher_builder().build()
    publisher.start()
    topic = Topic.of(topic_str)

    try:
        for i in range(count):
            payload = make_message()
            outbound_message = messaging_service.message_builder().build(
                json.dumps(payload)
            )
            publisher.publish(outbound_message, topic)
            print(f"  [{i + 1}/{count}] published to {topic_str}: {payload}")
            time.sleep(interval)
    finally:
        publisher.terminate()
        messaging_service.disconnect()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--class",
        dest="class_name",
        choices=list(CLASSES.keys()),
        default=None,
        help="Restrict to a single data class (default: all 3, in order: "
        "public, eu-ops, eu-pii).",
    )
    parser.add_argument("--count", type=int, default=20)
    parser.add_argument("--interval", type=float, default=1.0)
    args = parser.parse_args()

    config = load_config()
    classes_to_run = [args.class_name] if args.class_name else list(CLASSES.keys())

    # Each class is attempted independently -- one class failing (e.g. a
    # wrong password for just that credential) does not abort the others,
    # so a single run always at least TRIES all 3 destinations.
    failed = False
    for class_name in classes_to_run:
        try:
            publish_class(class_name, config, args.count, args.interval)
        except Exception as exc:  # noqa: BLE001 -- deliberately broad: keep going
            print(f"  WARN: klasse '{class_name}' mislukt ({exc}) -- ga door met de volgende klasse.")
            failed = True

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
