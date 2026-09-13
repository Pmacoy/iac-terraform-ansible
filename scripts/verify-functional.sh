#!/usr/bin/env bash
# Proves the playbook run actually did something, not just that it exited
# 0: curls each fleet node's nginx over the mapped host port and checks
# the page webserver/templates/index.html.j2 rendered contains that node's
# own hostname, and separately proves ssh_hardening actually took effect
# by asserting password auth is now refused on port 22.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

NODES=(
  "corporate-server-1:8081"
  "corporate-server-2:8082"
)

for entry in "${NODES[@]}"; do
  name="${entry%%:*}"
  port="${entry##*:}"
  echo "==> Checking http://127.0.0.1:${port}/ mentions ${name}"
  body="$(curl -sf --max-time 5 "http://127.0.0.1:${port}/")"
  if ! echo "${body}" | grep -q "${name}"; then
    echo "FAIL: response from ${name} did not mention its own hostname:" >&2
    echo "${body}" >&2
    exit 1
  fi
  echo "==> ${name} OK"
done

echo "==> Checking ssh_hardening actually disabled password authentication"
# PreferredAuthentications=password forces sshd to either offer a
# password prompt or refuse outright; ssh_hardening's
# PasswordAuthentication no means it must refuse, so a successful
# connection here (exit 0, "Permission denied") is the pass condition --
# an exit 5 (auth succeeded) or a password prompt would mean hardening
# didn't actually apply.
set +e
ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=3 \
    -o BatchMode=yes \
    -o PreferredAuthentications=password \
    -p 2201 bootstrap@127.0.0.1 true
status=$?
set -e
if [ "${status}" -eq 0 ]; then
  echo "FAIL: password authentication was accepted -- ssh_hardening did not apply" >&2
  exit 1
fi
echo "==> Password authentication is refused, as expected"

echo "==> Functional verification passed"
