#!/usr/bin/env bash
# pod-up.sh — run ON the deployed instance to bring the moon-pod router up, peer it
# into your goatnet's fabric (router-to-router), and publish THROUGH it.
#
# This is the real moon-pod path: a partner-side zenohd dials the fabric router over
# the mesh; a local publisher writes to the LOCAL pod router only, so anything that
# reaches the fabric provably transited the pod router.
#
# Two trust domains, on purpose:
#   - FABRIC link  : the pod router DIALS OUT to the fabric using the slot cert. That
#                    cert is client-auth only (EKU=clientAuth), which is exactly right
#                    for the outbound/client role.
#   - LOCAL link   : the pod router SERVES local clients. A client-auth cert can't be a
#                    TLS *server* cert, so we mint a tiny local CA + server/client certs
#                    for loopback. Local trust and fabric identity are cleanly separate.
#
# Secrets are read from ./pod.env (gitignored, delivered out-of-band):
#   SETUP_KEY / MGMT_URL / ROUTER_ENDPOINT / SLOT  ; cert material in ./bundle/{cert,key,ca}.pem
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$HERE"
# shellcheck disable=SC1091
source ./pod.env
B="$HERE/bundle"
for f in cert.pem key.pem ca.pem; do [ -f "$B/$f" ] || { echo "missing $B/$f"; exit 2; }; done

echo "==> [1/6] enroll on the mesh"
sudo netbird up --management-url "$MGMT_URL" --setup-key "$SETUP_KEY"
for _ in $(seq 1 30); do netbird status 2>/dev/null | grep -q "Management: Connected" && break; sleep 2; done
netbird status | grep -E "Management|NetBird IP" | sed 's/^/    /'

echo "==> [2/6] resolve the fabric router to its mesh IP (container needs no special DNS)"
HOSTPORT="${ROUTER_ENDPOINT#tls/}"; RHOST="${HOSTPORT%%:*}"; RPORT="${HOSTPORT##*:}"; RIP=""
for _ in $(seq 1 30); do
  RIP="$(getent hosts "$RHOST" 2>/dev/null | awk 'NR==1{print $1}' || true)"
  [ -n "$RIP" ] && break; sleep 2
done
[ -n "$RIP" ] || { echo "could not resolve $RHOST over the mesh"; exit 1; }
echo "    $RHOST -> $RIP:$RPORT"

echo "==> [3/6] lay fabric certs + mint a local loopback PKI for pod-side clients"
sudo mkdir -p /etc/zenoh/tls
sudo cp "$B/cert.pem" /etc/zenoh/tls/fabric-cert.pem
sudo cp "$B/key.pem"  /etc/zenoh/tls/fabric-key.pem
# local CA + server cert (serverAuth, for the listener) + client cert (clientAuth, for the publisher)
sudo bash -c '
cd /etc/zenoh/tls
umask 077
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout local-ca-key.pem -out local-ca.pem -days 2 -subj "/CN=pod-local-ca" 2>/dev/null
openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout local-srv-key.pem -out s.csr -subj "/CN=pod-local" 2>/dev/null
openssl x509 -req -in s.csr -CA local-ca.pem -CAkey local-ca-key.pem -CAcreateserial -out local-srv.pem -days 2 \
  -extfile <(printf "subjectAltName=IP:127.0.0.1,DNS:localhost\nextendedKeyUsage=serverAuth,clientAuth\n") 2>/dev/null
openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout local-cli-key.pem -out c.csr -subj "/CN=pod-local-pub" 2>/dev/null
openssl x509 -req -in c.csr -CA local-ca.pem -CAkey local-ca-key.pem -CAcreateserial -out local-cli.pem -days 2 \
  -extfile <(printf "extendedKeyUsage=clientAuth\n") 2>/dev/null
# the router validates BOTH the fabric server cert (zagros CA) and local clients (local CA)
cat "'"$B"'/ca.pem" local-ca.pem > combined-ca.pem
rm -f s.csr c.csr
'
echo "    fabric link = slot cert (clientAuth); local link = minted server/client certs"

echo "==> [4/6] render the pod router config (listen=local server cert, connect=slot cert)"
sudo tee /etc/zenoh/config.json5 >/dev/null <<EOF
{
  mode: "router",
  listen:  { endpoints: ["tls/0.0.0.0:7447"] },
  connect: { endpoints: ["tls/${RIP}:${RPORT}"] },
  transport: { link: { tls: {
    // local clients connect to THIS listener -> present a server-auth cert
    listen_certificate:  "/etc/zenoh/tls/local-srv.pem", listen_private_key: "/etc/zenoh/tls/local-srv-key.pem",
    // the pod DIALS OUT to the fabric as a client -> present the slot (client-auth) cert
    connect_certificate: "/etc/zenoh/tls/fabric-cert.pem", connect_private_key: "/etc/zenoh/tls/fabric-key.pem",
    // trust both: the fabric's CA (validate ZAGROS) + the local CA (validate pod-side clients)
    root_ca_certificate: "/etc/zenoh/tls/combined-ca.pem",
    enable_mtls: true, verify_name_on_connect: false,
  }}},
  plugins_loading: { enabled: true, search_dirs: ["/", "/opt/zenoh/plugins"] },
  access_control: {
    enabled: true, default_permission: "deny",
    rules: [
      { id: "firstparty", messages: ["put","delete","declare_subscriber","query","declare_queryable","reply"], flows: ["egress","ingress"], permission: "allow", key_exprs: ["${SLOT}/**"] },
      { id: "inbound",    messages: ["declare_subscriber","query","put","reply"], flows: ["egress","ingress"], permission: "allow", key_exprs: ["release/goat/**"] },
    ],
    subjects: [ { id: "mtls", link_protocols: ["tls"] } ],
    policies: [ { rules: ["firstparty","inbound"], subjects: ["mtls"] } ],
  },
}
EOF

echo "==> [5/6] start the pod router + wait for router-to-router peering"
sudo docker rm -f velmara-pod-router >/dev/null 2>&1 || true
sudo docker run -d --name velmara-pod-router --network host --restart unless-stopped \
  -e RUST_LOG=zenoh=info,zenoh_transport=debug \
  -v /etc/zenoh/config.json5:/etc/zenoh/config.json5:ro -v /etc/zenoh/tls:/etc/zenoh/tls:ro \
  eclipse/zenoh:1.9.0 -c /etc/zenoh/config.json5 >/dev/null
PEERED=0
for _ in $(seq 1 30); do
  if sudo docker logs velmara-pod-router 2>&1 | grep -q "New transport opened between"; then PEERED=1; break; fi
  sleep 2
done
if [ "$PEERED" = 1 ]; then
  echo "    PEERED ✓ $(sudo docker logs velmara-pod-router 2>&1 | grep 'New transport opened between' | tail -1 | sed -E 's/.*between ([0-9a-f]+) and ([0-9a-f]+).*/pod-router \1 <-> fabric \2/')"
else
  echo "    WARNING: no peering line; recent log:"; sudo docker logs velmara-pod-router 2>&1 | tail -5 | sed 's/^/      /'
fi

echo "==> [6/6] publish THROUGH the local pod router (connects to 127.0.0.1 only)"
TOK="cloud-$(date +%s)"
# run as root: the mTLS material under /etc/zenoh/tls is root-owned (mode 600).
sudo /opt/zenoh-venv/bin/python3 - "$SLOT" "$TOK" <<'PY'
import json, sys, time, zenoh
slot, tok = sys.argv[1], sys.argv[2]
c = zenoh.Config()
c.insert_json5("mode", '"client"')
c.insert_json5("connect/endpoints", json.dumps(["tls/127.0.0.1:7447"]))   # LOCAL pod router only
c.insert_json5("transport/link/tls/enable_mtls", "true")
c.insert_json5("transport/link/tls/verify_name_on_connect", "false")
c.insert_json5("transport/link/tls/connect_certificate", '"/etc/zenoh/tls/local-cli.pem"')
c.insert_json5("transport/link/tls/connect_private_key", '"/etc/zenoh/tls/local-cli-key.pem"')
c.insert_json5("transport/link/tls/root_ca_certificate", '"/etc/zenoh/tls/local-ca.pem"')
s = zenoh.open(c)
key = f"{slot}/live/{tok}"
for i in range(15):
    s.put(key, json.dumps({"from": "velmara-demo", "via": "cloud-pod-router", "seq": i, "tok": tok}).encode())
    print(f"    published {key} seq={i}")
    time.sleep(1.2)
s.close()
print(f"TOK={tok}")
PY
echo "==> done. Published via the pod router under ${SLOT}/live/${TOK}. Check the fabric panoscope."
