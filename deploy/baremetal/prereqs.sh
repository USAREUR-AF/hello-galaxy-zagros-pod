#!/usr/bin/env bash
# prereqs.sh — install the pod's prerequisites on an EXISTING host (bare metal /
# on-prem / a VM you already own). Idempotent. This is the bare-metal equivalent of
# the cloud path's cloud-init.yaml — same packages, run over SSH instead of at boot.
#
# Run as root (or via sudo) on the target. No secrets, no enrollment here — that
# happens in pod-up.sh once the signed bundle is delivered.
set -euo pipefail
echo "==> installing pod prerequisites (docker, netbird, zenoh client)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq docker.io python3-venv python3-pip curl jq gettext-base
systemctl enable --now docker
# NetBird client (enrollment happens later, in pod-up.sh, with the bundle key).
if ! command -v netbird >/dev/null 2>&1; then curl -fsSL https://pkgs.netbird.io/install.sh | sh; fi
# Isolated Zenoh client venv (PEP 668).
[ -x /opt/zenoh-venv/bin/python3 ] || python3 -m venv /opt/zenoh-venv
/opt/zenoh-venv/bin/pip install --quiet "eclipse-zenoh==1.9.0"
docker pull eclipse/zenoh:1.9.0
echo "==> prereqs done"
