# Partner run guide — stand the pod up against a live goatnet

The laptop loopback (`./run.sh`) proves the mechanics with no fabric and no credentials.
This guide is the **live** path: run the same pod against any appropriate goatnet whose
operators have granted you a slot, using a signed join bundle. Every step here needs that
goatnet. It can be
EFDI, the shared sandbox goatnet that partners are onboarded to (if you are onboarded to it); <!-- oss-allow: operator-approved public example goatnet -->
a goatlite you stand up yourself (goatcore's
[`docs/tutorials/00-goatlite.md`](https://github.com/usareur-af/goatcore/blob/main/docs/tutorials/00-goatlite.md)); or another
goatnet you have access to. The `zagros` profile is an example profile for the sandbox shape
described in [`usareur-af/zagros-moon-pod`](https://github.com/usareur-af/zagros-moon-pod)
(setup-key enrollment, per-uuid slot namespace).

You run the pod on your own host; everything environment-specific is carried in the bundle,
not configured by hand.

## What you receive at onboarding

1. A **signed join bundle** (`<your-handle>.cbor`) — carries your mesh setup-key, the goatnet's
   fabric router endpoint, your mTLS identity (your per-uuid slot), and the CA roots. It is
   the single source of truth; the pod reads everything from it.
2. The **`goat` CLI** for your platform (linux-amd64 / linux-arm64).

> Treat the bundle as a secret in transit. It activates on first use and expires; if it
> lapses, ask for a fresh one.

## Prerequisites on your host

- A Linux host you control, with the pod's state dir on a **LUKS-encrypted volume**.
- **Docker** + the compose plugin.
- A **mesh client**: stock NetBird is the sandbox on-ramp.
- The **`goat`** binary on `PATH`, and `envsubst` (from `gettext`).

## Bring-up

```
# 1. Join the goatnet's mesh with the setup-key from your bundle:
sudo netbird up --management-url <mgmt-url-from-onboarding> --setup-key <setup-key-from-onboarding>

# 2. Run first-boot with the zagros profile + your bundle. It verifies the bundle, extracts
#    your mTLS identity, renders the pod router config from the BUNDLE's router endpoint, and
#    starts the data plane. Re-runnable.
sudo ./host/first-boot.sh zagros /path/to/<your-handle>.cbor
```

first-boot does, in order: verify the bundle + extract certs (`goat profile init`) → lay the
Zenoh mTLS material → render the router config (endpoint from the bundle) → start
`zenoh-router` + `audit-sink` via `host/docker-compose.pod.yml` → install the `goat-doctor`
health timer.

## Verify

```
# Health — expect cert/router checks green:
sudo GOAT_PROFILE_DIR=/var/lib/goat-moon/goat-cli goat doctor --all

# Containers up:
docker ps    # goat-moon-zenoh-router + goat-moon-audit-sink

# Round-trip on your own namespace (your slot):
echo hi > /tmp/ping
sudo GOAT_PROFILE_DIR=/var/lib/goat-moon/goat-cli goat pub '<your-slot>/test/ping' --payload-file /tmp/ping
sudo GOAT_PROFILE_DIR=/var/lib/goat-moon/goat-cli goat sub '<your-slot>/**' --count 1
```

Your slot is the namespace your cert is bound to (the `PARTNER_NAMESPACE` first-boot
reported). A publish **outside** your slot is silently denied — that is expected; publish
only within it.

## Sending and receiving real data

- **From code:** [`../clients/python/`](../clients/python/) has worked publisher / subscriber
  examples — point them at your slot.
- **Inbound (bilateral):** when a bilateral inbound channel is granted, subscribe to the
  `release/goat/**` prefix.

## Trouble

- **`goat doctor` router check fails:** confirm the mesh is up (`netbird status` → Connected)
  and the bundle hasn't expired (`goat profile show`). The router endpoint comes from the
  bundle, so a stale bundle points at the wrong place — get a fresh one.
- **A container can't pull its image:** every pod image is public; run
  `tests/check-images-public.sh` to confirm reachability.
- **A publish "succeeds" but nothing arrives:** check you published *inside* your slot.
  Denials are silent by design.
