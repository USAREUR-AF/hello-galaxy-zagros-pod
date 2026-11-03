# hello-galaxy-zagros-pod

**A runnable, end-to-end example that stands a partner data-pod and its router up from
scratch, configures the router from a central source of truth, and proves data peers
across routers — on a laptop, in one command.**

This is a Hello Galaxy demo: a small, self-contained, runnable example of one thing done
right. It forks [`usareur-af/zagros-moon-pod`](https://github.com/usareur-af/zagros-moon-pod)
into a *worked, executable* instance for a fictional
partner — **Velmara Autonomous Systems Command** (Republic of Velmara) — and fills in the
parts a scaffold leaves as an exercise: the full stack standup, the rendered router
configuration, and an automated smoke test that shows data actually crossing between
routers.

## The questions this answers

It exists to answer a recurring set of questions about how router configuration is handled:

> *How are router configurations managed and synchronized across the network? Is there a
> tool/platform for centralized configuration management, deployment, and automation? As
> the network scales, can we manage configurations efficiently?*

Short answer: **yes, and you can run the proof here.** Router configs are generated from a
single registry, deployed by automation, and the routers synchronize themselves over an
encrypted mesh — no box is hand-edited. The full write-up is
[`docs/router-configuration-management.md`](docs/router-configuration-management.md); this
repo is the executable version of it.

## Run it

Prerequisites: `docker`, `openssl`, `python3` (+ `pip install pyyaml`), and the `goat` CLI
(built from [`usareur-af/goatcore`](https://github.com/usareur-af/goatcore): see its
[getting-started](https://github.com/usareur-af/goatcore/blob/main/docs/goat-cli-book/src/getting-started.md)).

```
./run.sh
```

That single command:

1. **renders** every router's config from one file (`stack/registry/fabric.yaml`),
2. **mints** a throwaway CA + mTLS certs,
3. **starts** two stock Zenoh routers — a partner *pod* router and a stand-in *fabric*
   (goat-side) router — peered over mTLS, and
4. **runs the smoke test**, which proves data peers both ways and that the pod's
   default-deny holds.

Expected tail:

```
▸ 1. Outbound — data peers pod-router → fabric-router
    ✓ the pod's publish crossed the peering and arrived at the goat side
▸ 2. Security — the pod's default-DENY holds
    ✓ an out-of-namespace publish was silently denied (never reached the goat side)
▸ 3. Inbound — bilateral data peers fabric-router → pod-router
    ✓ the fabric's bilateral publish crossed the peering and arrived at the pod

━━ SMOKE TEST PASSED ━━  data peers both ways; default-deny holds.
```

Other subcommands: `./run.sh render` (just show the config generation), `up`, `smoke`,
`down`, `logs`. The CI gate `tests/render-check.sh` proves config validity + router
peering with **no goat CLI**; the full `tests/smoke/loopback.sh` adds the goat-driven
data-delivery proof. Both run in GitHub Actions on every pull request (the smoke test with
the released goat CLI).

## What it demonstrates, mapped to the config-management story

| You see | Where | The point |
|---|---|---|
| One file describes the whole fabric | `stack/registry/fabric.yaml` | central source of truth — change here, not on the box |
| That file becomes every router's config | `stack/render.py` → `./run.sh render` | generated, consistent, reviewable; no hand-editing |
| Routers find and peer with each other | the smoke test | synchronization is automatic over mTLS — no central broker |
| Default-deny stops out-of-namespace data at the edge | smoke test #2 | the security posture is in the generated config, fleet-wide |
| Router identity is stable across restarts | `render-check` (deterministic id) | reproducible deployments |
| Adding a partner/router is a registry edit | `stack/registry/fabric.yaml` | this is how it scales |

## Two paths: loopback (the default) and a live goatnet

- **Loopback** (this repo's default): everything runs locally with a throwaway CA and a
  stand-in fabric router. No goatnet, no credentials — the fastest way to *see it work*.
- **A live goatnet**: run the same pod against any appropriate goatnet you have been granted
  a slot on, with a signed join bundle from that goatnet's operators. That can be
  EFDI, the shared sandbox goatnet that partners are onboarded to (if you are onboarded to it); <!-- oss-allow: operator-approved public example goatnet -->
  a goatlite you stand up yourself on one box (goatcore's quickstart
  [`docs/tutorials/00-goatlite.md`](https://github.com/usareur-af/goatcore/blob/main/docs/tutorials/00-goatlite.md), or the
  fuller step-by-step walk in
  [`usareur-af/hello-galaxy-goatenv`](https://github.com/usareur-af/hello-galaxy-goatenv));
  or another goatnet you have access to. The `zagros` profile is an example profile for the
  sandbox shape described in `zagros-moon-pod` (setup-key enrollment, per-uuid slot
  namespace). See
  [`docs/partner-run-guide.md`](docs/partner-run-guide.md) and
  [`tests/smoke/live-goatnet.md`](tests/smoke/live-goatnet.md).

| Step | Needs a goatnet? |
|---|---|
| `./run.sh`, `tests/render-check.sh`, `tests/smoke/loopback.sh` | no |
| `docs/partner-run-guide.md`, `tests/smoke/live-goatnet.md`, `host/first-boot.sh` | yes, plus a signed join bundle |
| `deploy/` (cloud box) and `deploy/baremetal/` | yes, plus a signed join bundle |

The pod hardcodes nothing stack-specific: which fabric, which identity, which namespace all
come from the registry (loopback) or the signed bundle (live). Switching environments is a
different registry/bundle, never a code change.

## Layout

```
hello-galaxy-zagros-pod/
├── run.sh                       one-command standup + smoke
├── stack/
│   ├── registry/fabric.yaml     THE central source of truth (routers, partners, ACLs)
│   ├── render.py                turns the registry into every router's config.json5
│   ├── templates/               pod-router + fabric-router json5 templates
│   ├── gen-certs.sh             throwaway loopback CA + leaf certs
│   └── docker-compose.yml       the two peered routers
├── tests/
│   ├── render-check.sh          CI gate: config validity + peering (no goat)
│   ├── smoke/loopback.sh        full smoke: data peers both ways (uses goat)
│   └── smoke/live-goatnet.md    the same checks against a live goatnet
├── docs/
│   ├── router-configuration-management.md   the stakeholder answer (read this)
│   ├── router-config.md         a worked walk-through of the rendered config
│   ├── architecture.md          how the pod is shaped + the data flow
│   └── partner-run-guide.md     run the pod against a live goatnet
├── profiles/zagros/profile.env  fallback values for a zagros-shaped sandbox goatnet
├── host/first-boot.sh           the real-bundle bring-up (live path)
├── clients/python/              worked publisher + subscriber
└── deploy/                      IaC: stand a pod on a CLOUD box (demo) + on BARE METAL (sovereign)
    └── baremetal/               on-prem target — where mission data at rest belongs
```

## Run it on a real host

- **Cloud (demo, throwaway):** [`deploy/`](deploy/) — Terraform stands up a small box; the pod's
  own router peers router-to-router with the goatnet's fabric router. Destroy it after.
- **Bare metal (sovereign, operational):** [`deploy/baremetal/`](deploy/baremetal/) — the same pod
  on a host you own. By principle, mission data at rest lives here, not in the cloud.

Both deliver the signed bundle out-of-band; no secrets or account particulars are ever committed.

## License

Apache-2.0. See [`LICENSE`](LICENSE).
