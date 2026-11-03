#!/usr/bin/env bash
# loopback.sh — the self-contained smoke test. PROVES, with no live fabric:
#
#   1. data peers pod-router → fabric-router   (a publish at the pod arrives at the goat side)
#   2. the pod's default-DENY holds            (a publish outside the namespace never crosses)
#   3. bilateral inbound peers fabric → pod    (release/goat data arrives at the pod)
#
# Assumes the loopback stack is already up (run.sh stands it up, then calls this). It
# drives the REAL `goat` CLI against the two REAL stock zenoh routers over mTLS. Nothing
# is mocked; the only thing not-production is that the fabric router is a permissive
# stand-in so the test isolates the POD's behaviour.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/common.sh"

POD_PORT=17447
FAB_PORT=17448
SLOT="$(python3 "${HG_ROOT}/stack/render.py" "${HG_ROOT}/stack/registry/fabric.yaml" --slot 2>/dev/null \
        || yq -r '.partners[0].slot' "${HG_ROOT}/stack/registry/fabric.yaml")"
RUN="r$$-$(date +%s)"

hg_banner "hello-galaxy-zagros-pod — bidirectional peering smoke test" \
          "two stock zenoh routers, mTLS, configs rendered from the central registry"
hg_note "partner slot (namespace): ${SLOT}"
hg_note "run token: ${RUN}"

# Build a goat profile per client role (distinct cert/ZID each — see gen-certs.sh).
hg_mkprofile producer-pod    "$POD_PORT"
hg_mkprofile consumer-pod    "$POD_PORT"
hg_mkprofile producer-fabric "$FAB_PORT"
hg_mkprofile consumer-fabric "$FAB_PORT"

# sub_then_pub <sub-role> <sub-key> <pub-role> <pub-key> <expect: yes|no>
# Starts a one-shot subscriber, waits until it has declared + propagated, publishes a
# uniquely-tokened message, then checks whether it arrived. Returns 0 if the observed
# outcome matches <expect>.
sub_then_pub() {
  local srole="$1" skey="$2" prole="$3" pkey="$4" expect="$5"
  local out err; out="$(mktemp)"; err="$(mktemp)"
  GOAT_PROFILE_DIR="${HG_PROFILES}/${srole}" GOAT_TIMEOUT=12 \
    goat --context loop sub "$skey" --count 1 >"$out" 2>"$err" &
  local subpid=$!
  # wait for the subscription to be declared (then a beat for it to propagate across the peering)
  for _ in $(seq 1 20); do grep -q "subscribed" "$err" 2>/dev/null && break; sleep 0.5; done
  sleep 2
  hg_goat "$prole" pub "$pkey" --payload "{\"tok\":\"${RUN}\"}" --encoding json >/dev/null 2>&1
  # poll for arrival
  local got=1
  for _ in $(seq 1 16); do if grep -q "$RUN" "$out" 2>/dev/null; then got=0; break; fi; sleep 0.5; done
  kill "$subpid" 2>/dev/null; wait "$subpid" 2>/dev/null
  rm -f "$out" "$err"
  if [ "$expect" = yes ]; then return "$got"; else [ "$got" -ne 0 ] && return 0 || return 1; fi
}

# --- Test 1 — outbound peering ----------------------------------------------------
hg_step "1. Outbound — data peers pod-router → fabric-router"
hg_say  "Subscribe ${SLOT}/** on the FABRIC side, publish ${SLOT}/test/ping on the POD side."
hg_cmd  "goat sub '${SLOT}/**'   (fabric)   |   goat pub '${SLOT}/test/ping'   (pod)"
sub_then_pub consumer-fabric "${SLOT}/**" producer-pod "${SLOT}/test/ping" yes
hg_assert "the pod's publish crossed the peering and arrived at the goat side" $?

# --- Test 2 — default-deny --------------------------------------------------------
hg_step "2. Security — the pod's default-DENY holds"
hg_say  "Publish OUTSIDE the namespace (forbidden/**) on the POD side; it must NOT cross."
hg_cmd  "goat sub 'forbidden/**'  (fabric)  |   goat pub 'forbidden/intrusion'  (pod)"
sub_then_pub consumer-fabric "forbidden/**" producer-pod "forbidden/intrusion" no
hg_assert "an out-of-namespace publish was silently denied (never reached the goat side)" $?

# --- Test 3 — inbound bilateral ---------------------------------------------------
hg_step "3. Inbound — bilateral data peers fabric-router → pod-router"
hg_say  "Subscribe release/goat/** on the POD side, publish on the FABRIC side."
hg_cmd  "goat sub 'release/goat/**'  (pod)  |   goat pub 'release/goat/test/pong'  (fabric)"
sub_then_pub consumer-pod "release/goat/**" producer-fabric "release/goat/test/pong" yes
hg_assert "the fabric's bilateral publish crossed the peering and arrived at the pod" $?

# --- verdict ----------------------------------------------------------------------
echo
if [ "$HG_FAILS" -eq 0 ]; then
  printf '%s━━ SMOKE TEST PASSED ━━%s  data peers both ways; default-deny holds.\n' "$C_G" "$C_0"
  exit 0
else
  printf '%s━━ SMOKE TEST FAILED ━━%s  %s assertion(s) failed.\n' "$C_R" "$C_0" "$HG_FAILS"
  printf '%sdebug: docker compose -f stack/docker-compose.yml logs%s\n' "$C_DIM" "$C_0"
  exit 1
fi
