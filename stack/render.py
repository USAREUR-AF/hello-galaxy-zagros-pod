#!/usr/bin/env python3
"""render.py — turn the central registry into every router's config.

This is the heart of the "centralized configuration management" story. It reads ONE
source of truth (stack/registry/fabric.yaml) and renders a complete config.json5 for
each router declared there. No router is ever hand-configured; you change the registry
and re-render, and every router gets a consistent config.

It mirrors the real goat fabric: the operator portal is the registry, and Ansible
renders each router from it. Here it is the same idea at laptop scale.

Usage:
    render.py <registry.yaml> <out_dir>
        Render every router in the registry to <out_dir>/<router-name>.config.json5
    render.py <registry.yaml> --router <name>
        Print one router's rendered config to stdout (used by gen + inspection).

Requires: python3 + pyyaml  (pip install pyyaml).
"""
import hashlib
import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("render.py needs PyYAML: pip install pyyaml")

HERE = Path(__file__).resolve().parent
TEMPLATES = HERE / "templates"

# Message sets, by intent.
WRITE_MSGS = ["put", "delete", "declare_subscriber", "query", "declare_queryable", "reply"]
READ_MSGS = ["declare_subscriber", "query", "put", "reply"]
ALL_MSGS = ["put", "delete", "declare_subscriber", "query", "declare_queryable", "reply"]
BOTH_FLOWS = ["egress", "ingress"]


def router_id(name: str) -> str:
    """Deterministic 32-hex router id from the router name — survives restarts,
    never random, never image-baked (mirrors ADR 1041 ZID pinning)."""
    return hashlib.sha256(f"hello-galaxy:{name}".encode()).hexdigest()[:32]


def rule(rid, msgs, key_exprs):
    return {
        "id": rid,
        "messages": msgs,
        "flows": BOTH_FLOWS,
        "permission": "allow",
        "key_exprs": key_exprs,
    }


def acl_for_pod(reg, partner_handle):
    """A pod router owns exactly one partner: allow write on its own namespace(s),
    allow read on the inbound-only prefixes. Everything else is default-denied."""
    partner = next(p for p in reg["partners"] if p["handle"] == partner_handle)
    write = list(partner.get("write", []))
    read = list(partner.get("read", []))
    inbound_only = [k for k in read if k not in write]
    rules = [rule("pod-firstparty", WRITE_MSGS, write)]
    if inbound_only:
        rules.append(rule("pod-inbound", READ_MSGS, inbound_only))
    return rules


def acl_for_fabric(reg):
    """The goat-side receiver admits every declared partner namespace + the bilateral
    inbound. In the loopback this is permissive on purpose so the test exercises the
    POD's default-deny; the real core router is per-tenant and NOT permissive."""
    keys = []
    for p in reg["partners"]:
        for k in p.get("write", []) + p.get("read", []):
            if k not in keys:
                keys.append(k)
    inbound = reg["fabric"]["inbound_namespace"].rstrip("/") + "/**"
    if inbound not in keys:
        keys.append(inbound)
    return [rule("fabric-admit", ALL_MSGS, keys)]


def render_one(reg, router):
    name = router["name"]
    role = router["role"]
    if role == "pod":
        rules = acl_for_pod(reg, router["partner"])
        tmpl = (TEMPLATES / "pod-router.json5.tmpl").read_text()
    elif role == "fabric":
        rules = acl_for_fabric(reg)
        tmpl = (TEMPLATES / "fabric-router.json5.tmpl").read_text()
    else:
        raise SystemExit(f"unknown router role: {role}")

    rule_ids = [r["id"] for r in rules]
    out = (
        tmpl.replace("__LISTEN_PORT__", str(router["listen_port"]))
        .replace("__INGRESS_ENDPOINT__", reg["fabric"]["ingress_endpoint"])
        .replace("__ROUTER_ID__", router_id(name))
        # json.dumps with indent keeps the rendered file readable.
        .replace("__ACL_RULES__", json.dumps(rules, indent=6).replace("\n", "\n    "))
        .replace("__ACL_RULE_IDS__", json.dumps(rule_ids))
    )
    return out


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    reg = yaml.safe_load(Path(argv[0]).read_text())

    # Convenience accessor used by the smoke test: print the first partner's slot anchor.
    if len(argv) >= 2 and argv[1] == "--slot":
        print(reg["partners"][0]["slot"])
        return

    if len(argv) >= 3 and argv[1] == "--router":
        sys.stdout.write(render_one(reg, next(r for r in reg["routers"] if r["name"] == argv[2])))
        return

    out_dir = Path(argv[1])
    out_dir.mkdir(parents=True, exist_ok=True)
    for router in reg["routers"]:
        dest = out_dir / f"{router['name']}.config.json5"
        dest.write_text(render_one(reg, router))
        print(f"rendered {router['name']:14s} ({router['role']:6s}) -> {dest}")


if __name__ == "__main__":
    main(sys.argv[1:])
