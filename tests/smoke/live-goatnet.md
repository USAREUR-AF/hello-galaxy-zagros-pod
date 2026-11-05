# Live-goatnet smoke (the slow path, on a host with a bundle)

The self-contained smoke (`loopback.sh`) proves the mechanics offline. This is the live
counterpart: the same pod, against a **real goatnet's fabric router**, using a signed join
bundle from that goatnet's operator. There is no stub fabric here, so every step needs the
goatnet.

## Prereqs

- A Linux host on the goatnet's mesh (see [`../../docs/partner-run-guide.md`](../../docs/partner-run-guide.md)).
- The partner's signed bundle (`<handle>.cbor`) + the `goat` CLI.

## Steps

The bundle is the one-time cert tarball the goatnet's operator hands you when your pod is
enrolled as a machine (`goat machine enroll <handle> --node-class MOON`). It holds
`<slot>-goat-cli.cbor` and, beside it, `<slot>-goat-cli-ca.pem`. Copy `profiles/zagros/` to
a profile of your own and replace `CHANGE-ME-zagros-uuid-slot` with your slot id.

```
# 0. goat trusts no goatnet until you add the root that signed your bundle:
sudo GOAT_PROFILE_DIR=/var/lib/goat-moon/goat-cli goat ca add /path/to/<slot>-goat-cli-ca.pem

# 1. Stand the pod up against the goatnet (your copy of the zagros profile):
sudo ./host/first-boot.sh <your-profile> /path/to/<slot>-goat-cli.cbor

# 2. Reach + identity:
sudo GOAT_PROFILE_DIR=/var/lib/goat-moon/goat-cli goat doctor --all
#    expect: mesh up, router TLS handshake ok, mTLS session ok.

# 3. Outbound — publish on your slot, observe it on the fabric:
sudo GOAT_PROFILE_DIR=/var/lib/goat-moon/goat-cli goat pub '<slot>/test/ping' --payload '{"hello":"galaxy"}' --encoding json --confirm
#    --confirm reports landed / not-confirmed (it reads the key back). A freshly enrolled slot
#    has no storage until the goatnet registers one for it, so --confirm reports
#    not-confirmed with "no storage is registered for the prefix". Prove delivery with a live
#    subscriber instead: someone on the goatnet who may read your slot runs
#    goat sub '<slot>/test/**' --follow, and sees your publish arrive.

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
