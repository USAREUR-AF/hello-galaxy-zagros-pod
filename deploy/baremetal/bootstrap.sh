#!/usr/bin/env bash
# bootstrap.sh — deploy the moon-pod onto an EXISTING host (bare metal / on-prem).
#
# This is the SOVEREIGN target. The cloud path (`..`) provisions a throwaway box
# for a demo; here the host already exists — yours, in your facility, where mission
# data at rest is allowed to live. The pod itself is byte-identical to the cloud
# demo: the ONLY difference is who owns the host and that nothing is provisioned in
# anyone's cloud. Same pod-up.sh, same bundle.
#
# It SSHes to your host, installs prerequisites, delivers the (gitignored) bundle +
# pod.env out-of-band, and runs the shared pod-up.sh. No secrets touch this repo.
#
# Config from ./target.env (gitignored):
#   HOST=...            # the on-prem host (IP or name you can SSH to)
#   SSH_USER=...        # a sudo-capable user
#   SSH_KEY=...         # path to your SSH private key
# Secrets reused from the shared parent dir (../bundle, ../pod.env) — same artifacts
# the cloud path uses; never committed.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$HERE"
# shellcheck disable=SC1091
source ./target.env
SSH="ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new ${SSH_USER}@${HOST}"
SCP="scp -i $SSH_KEY -o StrictHostKeyChecking=accept-new"
BUNDLE_DIR="${BUNDLE_DIR:-$HERE/../bundle}"
POD_ENV="${POD_ENV:-$HERE/../pod.env}"
POD_UP="$HERE/../pod-up.sh"
for p in "$BUNDLE_DIR/cert.pem" "$POD_ENV" "$POD_UP"; do [ -e "$p" ] || { echo "missing $p"; exit 2; }; done

echo "==> [1/3] install prerequisites on ${HOST}"
$SCP prereqs.sh "${SSH_USER}@${HOST}:/tmp/prereqs.sh"
$SSH 'sudo bash /tmp/prereqs.sh'

echo "==> [2/3] deliver bundle + pod.env + pod-up.sh (out-of-band; never via the repo)"
$SSH 'mkdir -p ~/pod/bundle'
$SCP "$BUNDLE_DIR"/* "${SSH_USER}@${HOST}:~/pod/bundle/"
$SCP "$POD_ENV" "${SSH_USER}@${HOST}:~/pod/pod.env"
$SCP "$POD_UP"  "${SSH_USER}@${HOST}:~/pod/pod-up.sh"

echo "==> [3/3] bring the pod up (enroll -> peer -> publish through the pod router)"
$SSH 'cd ~/pod && bash pod-up.sh'
echo "==> bare-metal deploy complete. Mission data at rest stays on THIS host."
