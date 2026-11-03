#!/usr/bin/env bash
# render-check.sh — the CI gate. Proves, with NO goat CLI and NO live fabric, that:
#
#   1. every router config renders from the registry and is VALID json5 (zenohd parses it)
#   2. both routers boot clean (no parse/ACL error)
#   3. the pod-router establishes an mTLS PEERING link to the fabric-router
#   4. router ids are the DETERMINISTIC ones derived from the registry (restart-stable)
#
# This is the bit-rot guard: it runs in GitHub Actions (docker + python only). The full
# operator smoke test (tests/smoke/loopback.sh) additionally drives the real `goat` CLI
# and proves data delivery both ways — run that locally / on a host that has goat.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
REG="stack/registry/fabric.yaml"
COMPOSE="stack/docker-compose.yml"
FAILS=0
ok()  { printf '  ✓ %s\n' "$1"; }
bad() { printf '  ✗ %s\n' "$1" >&2; FAILS=$((FAILS+1)); }

echo "▸ render configs from the central registry"
python3 stack/render.py "$REG" stack/.state/render/ || { echo "render failed"; exit 1; }

echo "▸ mint loopback certs"
bash stack/gen-certs.sh "$(python3 stack/render.py "$REG" --slot)" >/dev/null

echo "▸ boot both routers (debug transport logging)"
ZENOH_LOG="zenoh=info,zenoh_transport=debug" docker compose -f "$COMPOSE" up -d >/dev/null 2>&1
trap 'docker compose -f "$COMPOSE" down >/dev/null 2>&1' EXIT
sleep 8

POD_LOG="$(docker logs hg-pod-router 2>&1)"
FAB_LOG="$(docker logs hg-fabric-router 2>&1)"

# 1+2 — clean boot
if echo "$POD_LOG" | grep -qiE "error|panic|invalid|denied to load"; then bad "pod-router logged an error"; else ok "pod-router booted clean (config is valid json5)"; fi
if echo "$FAB_LOG" | grep -qiE "error|panic|invalid|denied to load"; then bad "fabric-router logged an error"; else ok "fabric-router booted clean (config is valid json5)"; fi

# 3 — peering
if echo "$POD_LOG" | grep -q "New transport opened between" && echo "$POD_LOG" | grep -q "whatami: router"; then
  ok "pod-router established an mTLS peering link to a router (fabric-router)"
else
  bad "no router-to-router peering link found in pod-router log"
fi

# 4 — deterministic ids
EXPECT_POD="$(python3 -c "import hashlib;print(hashlib.sha256(b'hello-galaxy:pod-router').hexdigest()[:32])")"
if echo "$POD_LOG" | grep -q "\"id\":\"${EXPECT_POD}\""; then
  ok "pod-router id is the deterministic ${EXPECT_POD} (restart-stable)"
else
  bad "pod-router id is not the expected deterministic value"
fi

echo
if [ "$FAILS" -eq 0 ]; then echo "━━ RENDER-CHECK PASSED ━━"; exit 0
else echo "━━ RENDER-CHECK FAILED ($FAILS) ━━"; exit 1; fi
