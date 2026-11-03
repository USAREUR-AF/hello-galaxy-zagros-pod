# Contributing

This is a Hello Galaxy demo repo: a small, runnable example. Keep it that way.

## Bar

- **It must run.** `./run.sh` stands the loopback fabric up and the smoke test must pass.
  CI (`tests/render-check.sh`) gates config validity + router peering with no goat CLI.
- **Nothing faked.** The demo drives the real stock Zenoh routers and the real `goat` CLI.
  Where a behaviour is a deployment property rather than something you control, say so.
- **Self-contained + safe to develop in the open.** No internal infrastructure, hostnames,
  mesh IPs, credentials, or links into private repos. The example partner (Velmara
  Autonomous Systems Command / Republic of Velmara) is fictional; keep examples fictional.
- **Generated, never hand-edited.** Router configs come from `stack/registry/fabric.yaml`
  via `stack/render.py`. Don't commit a rendered `config.json5`; change the registry or the
  template.

## Changing the config model

- A registry value change is a re-render (`./run.sh render`).
- A change to the ACL *shape* lives in `stack/templates/` and affects every router — that is
  a reviewed change; explain why in the PR.

## Before opening a PR

```
./run.sh                      # loopback up + smoke passes
bash tests/render-check.sh    # the CI gate passes locally
shellcheck -x run.sh lib/*.sh stack/*.sh tests/*.sh tests/smoke/*.sh
```

Apache-2.0; sign-off (`git commit -s`) appreciated.
