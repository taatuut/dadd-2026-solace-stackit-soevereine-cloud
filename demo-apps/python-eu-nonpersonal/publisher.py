#!/usr/bin/env python3
"""Publishes non-personal, EU-bound Enewable operational data (aggregated grid
load per postcode area) to the local broker on enewable/eu/ops/grid/load,
using the Solace PubSub+ Python API.

This is intentionally *aggregated* data -- no individual customer or meter is
identifiable, only per-area totals -- which is why this class is allowed to
stay within the EU (Azure West Europe / Netherlands) instead of requiring the
sovereign-only STACKIT route used for raw PII.

Usage:
    pip install -r requirements.txt
    python publisher.py [--count 20] [--interval 1.0]
"""
from __future__ import annotations

import argparse
import json
import os
import random
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


def load_config() -> dict:
    here = Path(__file__).resolve().parent
    # Prefer this app's own .env, fall back to the shared local-broker/.env
    load_dotenv(here / ".env")
    load_dotenv(here.parent.parent / "local-broker" / ".env", override=False)

    return {
        "host": os.environ.get("LOCAL_SMF_HOST", "localhost:55554"),
        "vpn": os.environ.get("LOCAL_MSG_VPN", "enewable"),
        "username": os.environ.get("PUB_EU_OPS_USER", "pub-eu-ops"),
        "password": os.environ["PUB_EU_OPS_PASSWORD"],
    }


def make_message() -> dict:
    return {
        "source": "enewable-grid-telemetry",
        "type": "grid-load-aggregate",
        "postcodeArea": random.choice(POSTCODE_AREAS),
        "loadKw": round(random.uniform(400.0, 1200.0), 1),
        "sampleSizeMeters": random.randint(50, 500),
        "classification": "non-personal-eu",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--count", type=int, default=20)
    parser.add_argument("--interval", type=float, default=1.0)
    parser.add_argument("--topic", default="enewable/eu/ops/grid/load")
    args = parser.parse_args()

    config = load_config()

    messaging_service = (
        MessagingService.builder()
        .from_properties(
            {
                transport_layer_properties.HOST: config["host"],
                service_properties.VPN_NAME: config["vpn"],
                authentication_properties.SCHEME_BASIC_USER_NAME: config["username"],
                authentication_properties.SCHEME_BASIC_PASSWORD: config["password"],
            }
        )
        .build()
    )
    messaging_service.connect()

    publisher = messaging_service.create_direct_message_publisher_builder().build()
    publisher.start()
    topic = Topic.of(args.topic)

    try:
        for i in range(args.count):
            payload = make_message()
            outbound_message = messaging_service.message_builder().build(
                json.dumps(payload)
            )
            publisher.publish(outbound_message, topic)
            print(f"[{i + 1}/{args.count}] published to {args.topic}: {payload}")
            time.sleep(args.interval)
    finally:
        publisher.terminate()
        messaging_service.disconnect()


if __name__ == "__main__":
    main()
