# shellcheck shell=bash
# common.sh — shared helpers + narration for the hello-galaxy-zagros-pod demo scripts.
#
# House style of the Hello Galaxy series: a script that drives the REAL tools (here:
# stock zenohd in docker + the real `goat` CLI) and narrates what is happening, with
# explicit pass/fail assertions. Nothing is faked.

set -o pipefail

HG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HG_ROOT
HG_STATE="${HG_ROOT}/stack/.state"
HG_TLS="${HG_STATE}/tls"
HG_PROFILES="${HG_STATE}/profiles"

# --- colours / narration ----------------------------------------------------------
if [ -t 1 ]; then C_G=$'\033[32m'; C_R=$'\033[31m'; C_DIM=$'\033[2m'; C_B=$'\033[1m'; C_0=$'\033[0m'
else C_G=; C_R=; C_DIM=; C_B=; C_0=; fi
HG_FAILS=0

hg_banner() { printf '\n%s━━ %s ━━%s\n' "$C_B" "$1" "$C_0"; [ -n "${2:-}" ] && printf '%s%s%s\n' "$C_DIM" "$2" "$C_0"; }
hg_step()   { printf '\n%s▸ %s%s\n' "$C_B" "$1" "$C_0"; }
hg_note()   { printf '    %s%s%s\n' "$C_DIM" "$1" "$C_0"; }
hg_say()    { printf '    %s\n' "$1"; }
hg_cmd()    { printf '    %s$ %s%s\n' "$C_DIM" "$1" "$C_0"; }
hg_pass()   { printf '    %s✓%s %s\n' "$C_G" "$C_0" "$1"; }
hg_fail()   { printf '    %s✗%s %s\n' "$C_R" "$C_0" "$1" >&2; HG_FAILS=$((HG_FAILS+1)); }

# hg_assert "<label>" <condition-rc 0/1>
hg_assert() { if [ "$2" -eq 0 ]; then hg_pass "$1"; else hg_fail "$1"; fi; }

# --- prereqs ----------------------------------------------------------------------
hg_need() {
  local missing=0
  for t in "$@"; do
    command -v "$t" >/dev/null 2>&1 || { printf '%s missing required tool: %s%s\n' "$C_R" "$t" "$C_0" >&2; missing=1; }
  done
  if [ "$missing" -ne 0 ]; then
    cat >&2 <<EOF
${C_DIM}install hints:
  docker  -> https://docs.docker.com/get-docker/
  goat    -> the goat CLI, built from https://github.com/usareur-af/goatcore (crates/goat-cli)
  openssl -> system package manager
  python3 -> system package manager  (+ pip install pyyaml)${C_0}
EOF
    return 1
  fi
}

# --- build a goat profile dir for a client role pointing at a loopback router -------
# hg_mkprofile <role> <host_port>
#   role      = a cert minted by gen-certs.sh (producer-pod, consumer-fabric, ...)
#   host_port = the published host port of the router this role talks to (17447/17448)
hg_mkprofile() {
  local role="$1" port="$2"
  local dir="${HG_PROFILES}/${role}/contexts/loop"
  mkdir -p "$dir"
  cp "${HG_TLS}/${role}-cert.pem" "${dir}/mtls.cert.pem"
  cp "${HG_TLS}/${role}-key.pem"  "${dir}/mtls.key.pem"
  cp "${HG_TLS}/ca-roots.pem"     "${dir}/ca-roots.pem"
  printf 'router_endpoint = "tls/127.0.0.1:%s"\ndevice_id = "%s"\n' "$port" "$role" > "${dir}/profile.toml"
  printf 'current_context = "loop"\n' > "${HG_PROFILES}/${role}/config.toml"
}

# run goat as a given client role: hg_goat <role> <goat-args...>
hg_goat() { local role="$1"; shift; GOAT_PROFILE_DIR="${HG_PROFILES}/${role}" goat --context loop "$@"; }
