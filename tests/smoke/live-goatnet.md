# Live-goatnet smoke (the slow path, on a host with a bundle)

The self-contained smoke (`loopback.sh`) proves the mechanics offline. This is the live
counterpart: the same pod, against a **real goatnet's fabric router**, using a signed join
bundle from that goatnet's operator. There is no stub fabric here, so every step needs the
goatnet.

## Prereqs

- A Linux host on the goatnet's mesh (see [`../../docs/partner-run-guide.md`](../../docs/partner-run-guide.md)).
- The partner's signed bundle (`<handle>.cbor`) + the `goat` CLI.

## Steps

```
# 1. Stand the pod up against the goatnet (zagros = the sandbox-shaped profile):
sudo ./host/first-boot.sh zagros /path/to/<handle>.cbor

# 2. Reach + identity:
sudo GOAT_PROFILE_DIR=/var/lib/goat-moon/goat-cli goat doctor --all
#    expect: mesh up, router TLS handshake ok, mTLS session ok.

# 3. Outbound — publish on your slot, observe it on the fabric:
sudo GOAT_PROFILE_DIR=/var/lib/goat-moon/goat-cli goat pub '<slot>/test/ping' --payload '{"hello":"galaxy"}' --encoding json --confirm
#    --confirm reports landed / not-confirmed (it reads the key back).

# 4. Inbound (when a bilateral grant exists) — subscribe to release/goat:
sudo GOAT_PROFILE_DIR=/var/lib/goat-moon/goat-cli goat sub 'release/goat/**' --follow

# 5. Audit — the audit-sink is subscribing your namespace; check its metrics:
curl -s localhost:9303/metrics | grep -i audit | head
```

## What "passing" looks like

- `goat doctor` chain green (mesh → router TLS → mTLS session).
- A `goat pub --confirm` on your slot reports **landed**.
- A publish **outside** your slot reports **not-confirmed** (silently denied by the fabric ACL).
- The audit-sink metrics increment as your namespace sees traffic.

This is the same three properties the loopback proves (outbound peers, default-deny holds,
inbound peers) — verified against the live fabric instead of a stand-in.
