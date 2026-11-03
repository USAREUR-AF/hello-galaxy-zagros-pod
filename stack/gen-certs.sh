#!/usr/bin/env bash
# gen-certs.sh — mint a throwaway CA + the leaf certs the loopback demo needs.
#
# In a real pod you NEVER do this: your mTLS identity arrives in the signed join
# bundle and first-boot extracts it. This script exists only so the self-contained
# loopback smoke test has a complete, offline PKI to prove peering with. Everything
# it writes lands under stack/.state/ (gitignored) and is safe to delete.
#
# It mints:
#   - one CA (root of trust for the whole loopback)
#   - one leaf per ROUTER   (pod-router, fabric-router)
#   - one leaf per CLIENT ROLE used by the smoke test, each with a DISTINCT CN so each
#     gets a distinct Zenoh session id. (goat pins its ZID to a 32-hex slot CN per
#     ADR 1039; two concurrent clients sharing one slot cert collide on MAX_LINKS — so
#     the pod producer uses the slot CN, and the other roles use their own names.)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TLS="${HERE}/.state/tls"
SLOT="${1:?usage: gen-certs.sh <slot-anchor-32hex>}"
rm -rf "$TLS"; mkdir -p "$TLS"
cd "$TLS"

# --- CA --------------------------------------------------------------------------
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
  -keyout ca-key.pem -out ca-roots.pem -days 7 \
  -subj "/CN=hello-galaxy-loopback-ca" 2>/dev/null

# mint <name> <cn> [extra-SAN-csv]
mint() {
  local name="$1" cn="$2" extra="${3:-}"
  local san="DNS:localhost,DNS:${name},DNS:${cn},IP:127.0.0.1"
  [ -n "$extra" ] && san="${san},${extra}"
  openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -keyout "${name}-key.pem" -out "${name}.csr" -subj "/CN=${cn}" 2>/dev/null
  openssl x509 -req -in "${name}.csr" -CA ca-roots.pem -CAkey ca-key.pem -CAcreateserial \
    -out "${name}-cert.pem" -days 7 \
    -extfile <(printf 'subjectAltName=%s\n' "$san") 2>/dev/null
  rm -f "${name}.csr"
}

# Routers.
mint pod-router    pod-router
mint fabric-router fabric-router

# Client roles. The pod producer carries the SLOT CN (demonstrates ZID pinning); the
# rest carry their own names so concurrent clients never collide.
mint producer-pod    "$SLOT"
mint consumer-pod    hello-galaxy-pod-consumer
mint producer-fabric hello-galaxy-fabric-producer
mint consumer-fabric hello-galaxy-fabric-observer

rm -f ca.srl ./*.csr
echo "minted CA + $(find . -name '*-cert.pem' | wc -l | tr -d ' ') leaf certs into ${TLS}"
