# Router configuration: management, synchronization, and scale

This is the direct answer to three recurring questions:

1. How are router configurations managed and synchronized across the network?
2. Is there a tool/platform for centralized configuration management, deployment, and automation?
3. As the network scales, can configurations be managed efficiently?

The short answer to all three is **yes**, and the rest of this repo lets you run the proof.
Below is the model; everything in it is exercised by `./run.sh`.

## 1. Management — configuration as code, from one source of truth

Router configurations are **not hand-edited on the box**. Each router's config is *generated*
from a single declared source of truth and rendered by automation.

In this repo that source of truth is [`stack/registry/fabric.yaml`](../stack/registry/fabric.yaml):
one readable file that names every router, every participant, and what each participant is
allowed to write and read. [`stack/render.py`](../stack/render.py) turns it into a complete
`config.json5` for each router. You can watch it happen:

```
./run.sh render
```

Change a value in the registry, re-render, and every affected router gets a new, consistent
config. The per-router file is an *output*, never a place you edit. Because the source of
truth is a file in version control, every configuration change is reviewed, diffed, and
reversible — the same discipline as application code.

This mirrors the real goat fabric exactly, just shrunk to laptop scale:

| Here (the demo) | The real fabric |
|---|---|
| `stack/registry/fabric.yaml` | the operator **portal** registry (the declared issuance set) |
| `stack/render.py` | **Ansible** roles that render each router from the registry |
| `config.json5` per router | the rendered router config deployed to each host |
| a throwaway CA | the per-goatnet CA; each router's mTLS identity rides a signed bundle |

The principle is the one constant: **declare intent centrally, generate the per-box config,
never hand-configure a router.**

## 2. Deployment + automation — one command, reproducible

Configuration is applied by automation, not by logging into routers:

- **One command deploys.** Here it is `./run.sh up`; on the real fabric it is an Ansible
  play (a one-time bootstrap per host, then a fast routine refresh for changes).
- **Images are pinned by content digest.** The router image is referenced by an exact
  `sha256` (see [`stack/docker-compose.yml`](../stack/docker-compose.yml)), so every router
  in the fleet runs the identical, known binary — no "latest" drift.
- **Router identity is deterministic.** Each router's id is derived from its name, not
  random and not baked into the image (`render.py`'s `router_id`). A router comes back with
  the same identity after a restart, which keeps routing, audit, and topology stable. The CI
  gate asserts this:

  ```
  ✓ pod-router id is the deterministic 726a165c3499293e8cab0ddc95b16058 (restart-stable)
  ```

- **The same artifact runs everywhere.** The pod hardcodes nothing environment-specific.
  Which fabric, which identity, which namespace all arrive from the registry (loopback) or
  the signed join bundle (a live goatnet). Moving a pod to another goatnet is a different
  bundle, never a code change.

There is no manual "edit the router and reload" step in which a box can silently drift from
intent.

## 3. Synchronization — the routers keep themselves in sync

Two distinct things are kept in sync, by two distinct mechanisms:

**Configuration intent → routers.** Handled centrally as in §1–2: one registry regenerates
every router, so all routers reflect the same intent by construction. There is no
router-to-router config gossip to go stale.

**Routers → each other (the live data plane).** Routers find and connect to each other
automatically over an encrypted mesh (WireGuard) plus the fabric's own peer discovery. There
is **no central broker** to bottleneck or to keep manually in sync, and routers re-establish
their links and identity automatically after a restart or outage. The smoke test proves a
publish at one router arrives at another with nothing but the rendered configs in play:

```
✓ the pod's publish crossed the peering and arrived at the goat side
✓ the fabric's bilateral publish crossed the peering and arrived at the pod
```

The security posture travels with the config: each pod router default-**denies** everything
outside its own namespace, so an out-of-namespace publish never crosses — proven in the test
even against a deliberately wide-open receiver:

```
✓ an out-of-namespace publish was silently denied (never reached the goat side)
```

That deny is in the *generated* config, which means it is applied uniformly across the
fleet, not configured by hand per box.

## 4. Scale — adding routers is a registry edit

Because every router is generated from the registry, growing the network is adding entries,
not redesigning anything:

- **Add a participant** → add a `partners:` entry (its namespace and access). Re-render; the
  owning router picks up exactly its rules.
- **Add a router/site** → add a `routers:` entry. Re-render; it gets a complete, consistent
  config and a deterministic identity.
- **Pod routers stay simple as the fleet grows.** A pod router is single-tenant — it carries
  exactly one participant and a tiny default-deny ACL, regardless of how large the overall
  fabric is. The multi-tenant complexity lives only on the goat-side core/ingress routers,
  not replicated to every edge.
- **Standing up a whole new goatnet is itself scripted** — a turnkey sequence, so a new
  site is a parameterized run rather than a bespoke effort.

The same registry-driven model that manages two routers here manages hundreds. Nothing in
the model changes with fleet size; only the number of rows in the registry does.

## Try the scale point yourself

Add a second partner to [`stack/registry/fabric.yaml`](../stack/registry/fabric.yaml) (copy
the `velmara-demo` block, give it a new `handle`, `slot`, and namespaces), add a second
`pod-router` for it, then `./run.sh render`. You will see a second, fully-formed router
config appear — generated, consistent, and never hand-written. That is the whole answer in
one edit.

## See also

- [`router-config.md`](router-config.md) — a line-by-line walk-through of a rendered config.
- [`architecture.md`](architecture.md) — how the pod is shaped and where the router sits.
- [`partner-run-guide.md`](partner-run-guide.md) — the same pod against a live goatnet.
