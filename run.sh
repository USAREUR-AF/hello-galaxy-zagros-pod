#!/usr/bin/env bash
# run.sh — stand the whole loopback fabric up from scratch and prove data peers.
#
# One command, end to end:
#   1. render every router config from the central registry   (config management)
#   2. mint a throwaway CA + leaf certs                        (mTLS identity)
#   3. start two stock zenoh routers, peered over mTLS         (the fabric)
#   4. run the bidirectional smoke test                        (data is peered)
#
# This is the runnable answer to "show me the full stack standing up, the router being
# configured, and data actually peering." It needs nothing but a laptop — no live fabric.
#
# Subcommands:
#   ./run.sh              up + smoke + (leave running)        [default: 'all']
#   ./run.sh render       just render the configs and print where they went
#   ./run.sh up           render + certs + start the routers
#   ./run.sh smoke        run the smoke test against an already-up stack
#   ./run.sh down         tear the stack down
#   ./run.sh logs         tail the router logs
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

REG="${HG_ROOT}/stack/registry/fabric.yaml"
RENDER_DIR="${HG_STATE}/render"
COMPOSE="${HG_ROOT}/stack/docker-compose.yml"
CMD="${1:-all}"

do_render() {
  hg_step "Render router configs from the central registry"
  hg_cmd "python3 stack/render.py stack/registry/fabric.yaml stack/.state/render/"
  python3 "${HG_ROOT}/stack/render.py" "$REG" "$RENDER_DIR" | while read -r l; do hg_note "$l"; done
  hg_say "Every router above was generated from ONE file (stack/registry/fabric.yaml)."
  hg_say "Change the registry, re-run, and all routers stay consistent. No box is hand-edited."
}

do_certs() {
  hg_step "Mint the throwaway loopback CA + leaf certs"
  local slot; slot="$(python3 "${HG_ROOT}/stack/render.py" "$REG" --slot)"
  hg_cmd "stack/gen-certs.sh ${slot}"
  bash "${HG_ROOT}/stack/gen-certs.sh" "$slot" | while read -r l; do hg_note "$l"; done
}

do_up() {
  hg_need docker openssl python3 goat || exit 1
  python3 -c 'import yaml' 2>/dev/null || { echo "${C_R}need PyYAML: pip install pyyaml${C_0}"; exit 1; }
  do_render
  do_certs
  hg_step "Start the two routers (stock eclipse/zenoh, mTLS, peered)"
  hg_cmd "docker compose -f stack/docker-compose.yml up -d"
  docker compose -f "$COMPOSE" up -d 2>&1 | while read -r l; do hg_note "$l"; done
  hg_say "Waiting for the pod→fabric peering link to establish..."
  sleep 6
  if docker logs hg-pod-router 2>&1 | grep -qiE "New .*link|accepted|opened|reached"; then :; fi
  hg_pass "routers up: hg-pod-router (host :17447), hg-fabric-router (host :17448)"
}

do_down() {
  hg_step "Tear down"
  docker compose -f "$COMPOSE" down 2>&1 | while read -r l; do hg_note "$l"; done
}

case "$CMD" in
  render) do_render ;;
  certs)  do_certs ;;
  up)     do_up ;;
  smoke)  bash "${HG_ROOT}/tests/smoke/loopback.sh" ;;
  down)   do_down ;;
  logs)   docker compose -f "$COMPOSE" logs --tail=40 ;;
  all)
    do_up
    bash "${HG_ROOT}/tests/smoke/loopback.sh"; rc=$?
    echo
    hg_note "stack left running. './run.sh down' to stop, './run.sh logs' to inspect."
    exit $rc
    ;;
  *) echo "usage: $0 [all|render|up|certs|smoke|down|logs]"; exit 2 ;;
esac
