#!/usr/bin/env python3
"""subscribe.py — receive data from the fabric in plain Python (no goat CLI needed).

    pip install eclipse-zenoh==1.9.0

    # against the laptop loopback (after ./run.sh up), watching the partner namespace
    # from the FABRIC side:
    export GOAT_ROUTER=tls/127.0.0.1:17448
    export GOAT_CERT=stack/.state/tls/consumer-fabric-cert.pem
    export GOAT_KEY=stack/.state/tls/consumer-fabric-key.pem
    export GOAT_CA=stack/.state/tls/ca-roots.pem
    export GOAT_NAMESPACE=a1b2c3d4e5f60718293a4b5c6d7e8f90
    python3 clients/python/subscribe.py                 # <namespace>/** , follow forever
    python3 clients/python/subscribe.py 'release/goat/**'   # bilateral inbound

Pair it with publish.py to watch a message cross the router peering live.
"""
import json
import os
import sys
import time

import zenoh


def session() -> zenoh.Session:
    conf = zenoh.Config()
    conf.insert_json5("mode", '"client"')
    conf.insert_json5("connect/endpoints", json.dumps([os.environ["GOAT_ROUTER"]]))
    conf.insert_json5("transport/link/tls/enable_mtls", "true")
    conf.insert_json5("transport/link/tls/verify_name_on_connect", "false")
    conf.insert_json5("transport/link/tls/connect_certificate", json.dumps(os.environ["GOAT_CERT"]))
    conf.insert_json5("transport/link/tls/connect_private_key", json.dumps(os.environ["GOAT_KEY"]))
    conf.insert_json5("transport/link/tls/root_ca_certificate", json.dumps(os.environ["GOAT_CA"]))
    return zenoh.open(conf)


def main() -> None:
    keyexpr = sys.argv[1] if len(sys.argv) > 1 else f"{os.environ['GOAT_NAMESPACE']}/**"

    def on_sample(sample) -> None:
        print(f"{sample.key_expr}  {bytes(sample.payload).decode('utf-8', 'replace')}")

    with session() as s:
        s.declare_subscriber(keyexpr, on_sample)
        print(f"subscribed {keyexpr} — Ctrl-C to stop")
        while True:
            time.sleep(1)


if __name__ == "__main__":
    main()
