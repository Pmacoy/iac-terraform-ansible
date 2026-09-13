#!/usr/bin/env bash
# Generates the keypair the fleet containers and the Ansible inventory
# both expect, and writes BOOTSTRAP_SSH_PUBKEY into .env so docker-compose
# picks it up automatically. Safe to re-run -- it leaves an existing
# keypair alone.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

KEY_DIR=".ssh"
KEY_PATH="${KEY_DIR}/demo_key"

mkdir -p "${KEY_DIR}"

if [ ! -f "${KEY_PATH}" ]; then
  echo "==> Generating ${KEY_PATH}"
  ssh-keygen -t ed25519 -f "${KEY_PATH}" -N "" -C "iac-terraform-ansible-demo" -q
else
  echo "==> Reusing existing ${KEY_PATH}"
fi
chmod 600 "${KEY_PATH}"

PUBKEY="$(cat "${KEY_PATH}.pub")"

# Rewrite .env with just this one variable rather than appending -- keeps
# re-runs (e.g. after `rm .ssh/demo_key*`) from leaving a stale key behind.
printf 'BOOTSTRAP_SSH_PUBKEY=%s\n' "${PUBKEY}" > .env

echo "==> Wrote BOOTSTRAP_SSH_PUBKEY to .env"
