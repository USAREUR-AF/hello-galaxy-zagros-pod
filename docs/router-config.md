# A worked walk-through of the rendered router config

This walks through the actual `config.json5` the demo generates, so "the router is
configured" is something you can read rather than take on faith. Generate them first:

```
./run.sh render
# -> stack/.state/render/pod-router.config.json5
# -> stack/.state/render/fabric-router.config.json5
```

## Two ways a router gets its config — both generated, never hand-typed

This repo shows the two complementary ways a goat router is configured. Both follow the
same principle (generated from declared inputs, never edited on the box); they differ only
in scope.

| | Fleet model (this demo's loopback) | Single-pod model (the live path) |
|---|---|---|
| Input | the central registry `stack/registry/fabric.yaml` | the partner's signed join bundle |
| Renderer | `stack/render.py` | `host/first-boot.sh` (envsubst over `host/zenoh-router.json5.tmpl`) |
| Scope | every router in the fabric, consistently | the one pod, from its own bundle |
| Who runs it | the fabric operator (≈ Ansible from the portal) | the partner, once, on their host |

The fleet model is the answer to "how are configs managed across the network." The
single-pod model is how an individual partner pod self-configures from the bundle it was
handed. They meet in the middle: the registry is what the operator declares; the bundle is
what gets handed to the partner so their pod renders the same intent locally.

## The pod router, section by section

A rendered pod config is ~50 lines. Here is what each part is and why.

```json5
{
  mode: "router",
  listen:  { endpoints: ["tls/0.0.0.0:7447"] },          // local clients connect here (mTLS)
  connect: { endpoints: ["tls/fabric-router:7447"] },    // dial OUT to the goat side
  id: "726a165c3499293e8cab0ddc95b16058",                // deterministic, restart-stable
  transport: { link: { tls: { ... enable_mtls: true ... } } },  // one mTLS leaf, both directions
  plugins_loading: { ... },                              // load stock image plugins
  access_control: {
    enabled: true,
    default_permission: "deny",                          // <-- the security floor
    rules: [ pod-firstparty (your slot/**), pod-inbound (release/goat/**) ],
    subjects: [ { id: "mtls-peer", link_protocols: ["tls"] } ],
    policies: [ { rules: [...], subjects: ["mtls-peer"] } ],
  },
}
```

| Block | What it does | Where the value came from |
|---|---|---|
| `listen` | the local mTLS endpoint the pod's own clients (`goat`, the audit sink) connect to | router `listen_port` in the registry |
| `connect` | the goat-side endpoint the pod **dials out** to; the pod initiates, is never dialled into | `fabric.ingress_endpoint` (live: the bundle's `router_endpoint`) |
| `id` | a deterministic per-host router id so identity survives restarts | derived from the router name (`render.py`'s `router_id`) — never random, never image-baked |
| `transport.link.tls` | one mTLS leaf used as both listener and connector; every peer must present a cert rooted in the CA | certs from `gen-certs.sh` (live: extracted from the bundle) |
| `access_control` | **default-deny**, and the only allowed keys are this partner's namespaces | the partner's `write` / `read` lists in the registry |

### How the ACL is generated

`render.py` reads the partner's `write` and `read` from the registry and produces exactly
two rules:

- **`pod-firstparty`** — publish + subscribe on the partner's own namespace (its slot `/**`).
- **`pod-inbound`** — receive the bilateral inbound prefix (`release/goat/**`).

Everything else falls through to `default_permission: "deny"`. A publish outside the
namespace is silently dropped — which the smoke test proves (test 2). Add a namespace to
the registry and re-render, and the rule appears; you never touch the ACL by hand.

## Why the pod config is small — and the fabric config is not

A pod router is **single-tenant**: it carries exactly one partner, so its ACL is one subject
and two rules no matter how big the overall fabric is. The heavy, multi-tenant enforcement
lives on the **goat side** (the ingress gateway + core router), which authenticates every
pod, admits its data origin-scoped, and records provenance. The pod's own ACL is hygiene at
the edge, not the load-bearing control. That is why adding partners scales: complexity stays
centralized; edges stay simple.

In this repo the `fabric-router` is a deliberately permissive stand-in for that goat side —
just enough to accept the peering and route traffic so the smoke test can observe data
crossing. The real core router is not permissive.

## Changing the config

Never edit a rendered `config.json5` — it is overwritten on every render. Change the input:

| To change | Edit | Then |
|---|---|---|
| who can write/read what | `stack/registry/fabric.yaml` (the partner's `write`/`read`) | `./run.sh render` |
| the goat-side endpoint pods dial | `fabric.ingress_endpoint` (live: the bundle) | re-render / re-run first-boot |
| add a partner or a router | add a `partners:` / `routers:` entry | `./run.sh render` |
| the ACL *shape* itself (rare) | the template in `stack/templates/` | open a PR — it affects every router |
