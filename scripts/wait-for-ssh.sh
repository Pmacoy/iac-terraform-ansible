#!/usr/bin/env bash
# Blocks until every fleet host in the Ansible inventory accepts an SSH
# connection as the bootstrap user, or exits non-zero after a timeout.
# Containers take a few seconds to generate host keys and start sshd
# (see entrypoint.sh), so ansible-playbook's own SSH retries aren't
# enough of a first line of defense in CI.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

HOSTS=(
  "127.0.0.1:2201"
  "127.0.0.1:2202"
)
TIMEOUT_SECONDS=60
KEY_PATH=".ssh/demo_key"

for hostport in "${HOSTS[@]}"; do
  host="${hostport%%:*}"
  port="${hostport##*:}"
  echo "==> Waiting for SSH on ${host}:${port}"
  waited=0
  until ssh -i "${KEY_PATH}" \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=3 \
      -o BatchMode=yes \
      -p "${port}" bootstrap@"${host}" true 2>/dev/null; do
    waited=$((waited + 3))
    if [ "${waited}" -ge "${TIMEOUT_SECONDS}" ]; then
      echo "SSH on ${host}:${port} never came up after ${TIMEOUT_SECONDS}s" >&2
      exit 1
    fi
    sleep 3
  done
  echo "==> ${host}:${port} is up"
done
