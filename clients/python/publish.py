#!/usr/bin/env python3
"""publish.py — send data to the fabric from plain Python (no goat CLI needed).

The fabric is standard Zenoh over mTLS, so any Zenoh client works — this shows a
partner publishing with nothing but the eclipse-zenoh library and their certs.

    pip install eclipse-zenoh==1.9.0

    # against the laptop loopback (after ./run.sh up):
    export GOAT_ROUTER=tls/127.0.0.1:17447
    export GOAT_CERT=stack/.state/tls/producer-pod-cert.pem
    export GOAT_KEY=stack/.state/tls/producer-pod-key.pem
    export GOAT_CA=stack/.state/tls/ca-roots.pem
    export GOAT_NAMESPACE=a1b2c3d4e5f60718293a4b5c6d7e8f90
    python3 clients/python/publish.py            # one JSON sample
    python3 clients/python/publish.py 50 0.2     # 50 samples at 200ms

Publishes JSON under <namespace>/sensors/temp. Real payloads can be anything (bytes,
protobuf, CBOR); JSON here for legibility. A publish OUTSIDE your namespace is silently
denied by the pod's default-deny ACL.
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
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    interval = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0
    ns = os.environ["GOAT_NAMESPACE"]
    key = f"{ns}/sensors/temp"

    with session() as s:
        pub = s.declare_publisher(key)
        for i in range(n):
            payload = json.dumps({"ts": time.time(), "seq": i, "temp_c": 21.5 + i * 0.1})
            pub.put(payload.encode("utf-8"))
            print(f"published {key}  {payload}")
            if i + 1 < n:
                time.sleep(interval)


if __name__ == "__main__":
    main()
