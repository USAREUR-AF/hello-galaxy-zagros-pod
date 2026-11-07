# Contributing

This is a Hello Galaxy demo repo: a small, runnable example. Keep it that way.

## Bar

- **It must run.** `./run.sh` stands the loopback fabric up and the smoke test must pass.
  CI gates config validity + router peering with no goat CLI (`tests/render-check.sh`), and
  runs `./run.sh all` with the released goat CLI (the loopback smoke test).
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

Sign off every commit (`git commit -s`); see [Policy](#policy).

## Licence

Portions written by U.S. Federal government employees within the scope of their employment are not subject to copyright in the U.S.; in countries where copyright is recognized, they and all other contributions are licensed under the [Apache License 2.0](LICENSE). See [INTENT.md](INTENT.md). Contributions are accepted under the [Policy](#policy) below.

**NOTE: This CONTRIBUTING.md is for software contributions. You do not need to follow the Developer's Certificate of Origin (DCO) process for commenting on this repository's documentation, such as CONTRIBUTING.md, INTENT.md, etc. or for submitting issues.**

## Policy

### 1. Introduction

The project maintainer for this Project will only accept contributions using the Developer's Certificate of Origin 1.1 located at [developercertificate.org](https://developercertificate.org) ("DCO"). The DCO is a legally binding statement asserting that you are the creator of your contribution, or that you otherwise have the authority to distribute the contribution, and that you are intentionally making the contribution available under the license associated with the Project ("License").

### 2. Developer Certificate of Origin Process

Before submitting contributing code to this repository for the first time, you'll need to sign a Developer Certificate of Origin (DCO) (see below). To agree to the DCO, add a `Signed-off-by` line to every commit with `git commit -s`. At a high level, signing off tells us that you have the right to submit the work you're contributing and indicates that you consent to our treating the contribution in a way consistent with the license associated with this software (as described in [LICENSE](LICENSE) and [INTENT.md](INTENT.md)) and its documentation ("Project").

### 3. Important Points

Pseudonymous or anonymous contributions are permissible, but you must be reachable at the email address provided in the Signed-off-by line.

If your contribution is significant, you are also welcome to add your name and copyright date to the source file header.

U.S. Federal law prevents the government from accepting gratuitous services unless certain conditions are met. By submitting a pull request, you acknowledge that your services are offered without expectation of payment and that you expressly waive any future pay claims against the U.S. Federal government related to your contribution.

If you are a U.S. Federal government employee and use a `*.mil` or `*.gov` email address, we interpret your Signed-off-by to mean that the contribution was created in whole or in part by you and that your contribution is not subject to copyright protections.

### 4. DCO Text

The full text of the DCO is included below and is available online at [developercertificate.org](https://developercertificate.org):

```txt
Developer Certificate of Origin
Version 1.1

Copyright (C) 2004, 2006 The Linux Foundation and its contributors.
1 Letterman Drive
Suite D4700
San Francisco, CA, 94129

Everyone is permitted to copy and distribute verbatim copies of this
license document, but changing it is not allowed.

Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.
```
