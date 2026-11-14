# AGENTS.md

Instructions for AI coding agents, and a short version for anyone working here. [CONTRIBUTING.md](CONTRIBUTING.md) is the full process.

## What this repository is

hello-galaxy-zagros-pod stands up a partner data pod and its Zenoh router from nothing, renders every router's configuration from one registry file, and proves that data crosses between routers, on one machine. It is a worked instance of [zagros-moon-pod](https://github.com/USAREUR-AF/zagros-moon-pod) for a fictional partner.

It is one of the Hello Galaxy demonstrations: small, runnable examples, each showing one part of [goat](https://github.com/USAREUR-AF/goatcore). It holds no goat source code.

## Layout

| Path | What |
|---|---|
| `run.sh` | the runner: `all`, `render`, `logs`, `down` |
| `stack/` | the loopback stack: `registry/fabric.yaml` (the source of truth), `render.py`, `templates/`, the Compose file, certificate generation |
| `tests/render-check.sh` | checks configuration validity and router peering; needs no `goat` CLI |
| `tests/smoke/` | the smoke test that `run.sh all` runs |
| `host/`, `deploy/`, `profiles/`, `clients/` | running the pod on a real host: host scripts, Terraform and cloud-init, the `zagros` profile, client examples |

## Before you push

CI (`.github/workflows/ci.yml`) runs these. `run.sh all` needs Docker, `openssl` and the `goat` CLI on `PATH`.

```bash
python3 -m pip install pyyaml
bash tests/render-check.sh
shellcheck -x run.sh lib/common.sh stack/gen-certs.sh tests/*.sh tests/smoke/*.sh
bash run.sh all
bash run.sh down
```

Router configurations are generated. Change `stack/registry/fabric.yaml` or a file in `stack/templates/` and run `./run.sh render`; never commit a rendered `config.json5`.

## Rules

1. **Nothing internal and nothing real.** No internal hostname, mesh address, credential, key or link into a private repository. Keep every example fictional.
2. **Commits.** Conventional Commits subject (`fix(<component>): …`). Every commit is signed off (`git commit -s`, the DCO) and signed with a key GitHub verifies. The organization's required check `verified-commits` refuses a pull request that holds an unverified commit.
3. **Vulnerabilities** go through [SECURITY.md](SECURITY.md), never a public issue.

The contribution guide for goat as a whole is [goatcore CONTRIBUTING.md](https://github.com/USAREUR-AF/goatcore/blob/main/CONTRIBUTING.md).
