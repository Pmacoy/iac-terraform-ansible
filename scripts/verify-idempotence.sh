#!/usr/bin/env bash
# Runs the site playbook a second time (the first run is CI's own "real"
# apply) and fails if it reports any changed or failed tasks. A role that
# isn't actually idempotent -- e.g. a shell command with no changed_when
# guard -- passes a single run just fine and only shows up here, which is
# the whole reason this check exists as a separate step instead of trusting
# the first run alone.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUTPUT="$(mktemp)"
trap 'rm -f "${OUTPUT}"' EXIT

echo "==> Re-running ansible/playbooks/site.yml to check for idempotence"
ansible-playbook -i ansible/inventory/docker-hosts.ini ansible/playbooks/site.yml \
  | tee "${OUTPUT}"

echo "==> Checking play recap for changed/failed tasks"
# Recap lines look like:
#   corporate-server-1 : ok=12   changed=0    unreachable=0    failed=0 ...
recap="$(grep -A100 'PLAY RECAP' "${OUTPUT}")"
echo "${recap}"

if echo "${recap}" | grep -qE 'changed=[1-9]'; then
  echo "FAIL: second run reported changed tasks -- something isn't idempotent" >&2
  exit 1
fi
if echo "${recap}" | grep -qE 'failed=[1-9]|unreachable=[1-9]'; then
  echo "FAIL: second run reported failed/unreachable hosts" >&2
  exit 1
fi

echo "==> Idempotent: second run made no changes"
