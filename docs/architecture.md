# Architecture — how the pod is shaped and where the router sits

A moon-pod is a small, single-host appliance that exchanges data with the goat fabric through
its own router, without joining the fabric wholesale. This repo is a worked instance of that for
the fictional **Velmara Autonomous Systems Command**. What a moon-pod is for today, and what it
is not, is in [Run it on a real host](../README.md#run-it-on-a-real-host).

## The two things this repo runs

### 1. The loopback fabric (default; what `./run.sh` stands up)

```
        ┌─────────────────────────┐         ┌──────────────────────────────┐
        │  pod-router (Velmara)    │  mTLS   │  fabric-router (goat-side     │
        │  default-DENY            │ peering │  stand-in; permissive)        │
        │  owns slot/** only       │ ───────▶│  routes + delivers            │
        └─────────────────────────┘         └──────────────────────────────┘
              ▲ host :17447                          ▲ host :17448
              │ goat pub/sub (pod side)              │ goat pub/sub (fabric side)
```

Both routers are stock `eclipse/zenoh`, both configs rendered from `stack/registry/fabric.yaml`.
The smoke test drives the real `goat` CLI against each side to prove data crosses the peering
both ways and that the pod's default-deny holds. No live fabric, no credentials.

### 2. The live pod (against a goatnet)

```
Partner host (systemd)
  mesh client (stock netbird on the sandbox)        joins the goatnet mesh
  goat CLI                                            operator surface

docker-compose (network_mode: host)                  host/docker-compose.pod.yml
  zenoh-router   eclipse/zenoh:1.9.0                  data plane; mTLS; ACL slot/**
  audit-sink     goat-audit-subscriber               observe-only (subscribe + metrics)

host systemd timer
  goat-doctor    periodic `goat doctor` health blob
```

Here the pod dials a **real** goatnet's fabric router. Everything environment-specific — the
fabric endpoint, the mTLS identity (Velmara's per-uuid slot), the CA roots — arrives in the
**signed join bundle** and `host/first-boot.sh` lays it down. See
[`partner-run-guide.md`](partner-run-guide.md).

## Why the mesh client is on the host, not in a container

The one genuinely host-shaped piece (the WireGuard mesh client) runs as a host service for
kernel WireGuard, boot persistence + auto-reconnect, and no privileged container. The
data-plane containers use `network_mode: host` so they bind the pod's mesh IP directly.

## The data flow

A partner **publishes** under its own namespace (its slot `/**`); the pod router admits that
egress and forwards it over the peering to the goat side. When the relationship is bilateral,
the fabric **publishes back** under `release/goat/**`, which the pod router admits as ingress
and delivers to the partner's subscribers. Anything outside those namespaces is denied at the
pod's edge.

## What is goat-side, not pod code

The real receiver for a pod's data is a goat-operated **ingress gateway**: it authenticates
the pod's verified peering identity, admits its data origin-scoped, and records provenance —
a moon-pod is a non-goat↔goat (Tier-2) peer, so it does not federate directly into a core
router. In the loopback that gateway is approximated by the permissive `fabric-router`; in
a live goatnet it is the load-bearing enforcement. The pod is built to plug into it with no
rework: the pod publishes its own namespace regardless; the admitted shape is the receiver's
concern.
