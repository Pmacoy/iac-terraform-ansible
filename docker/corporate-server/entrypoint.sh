#!/usr/bin/env bash
# Container entrypoint -- runs as PID 1. Stands in for the handful of
# things a real cloud provider's first-boot process (cloud-init, EC2 user
# data) would do before configuration management ever gets a chance to
# connect: make sure the box has host keys and a way in.
set -euo pipefail

# Host keys aren't baked into the image -- that would mean every container
# built from it shares the same identity, which is both wrong and a minor
# secret-in-an-image smell. Generate them fresh on first boot instead, the
# same way a real freshly-provisioned instance would.
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
  ssh-keygen -A
fi

# The bootstrap user's authorized key is supplied at *container start*
# (a docker-compose environment variable, itself populated by
# scripts/generate-ssh-key.sh) rather than baked into the image at build
# time. That means the same image works for anyone who clones this repo
# and generates their own keypair, and no private key material ever
# touches the image or this repo.
install -d -m 700 -o bootstrap -g bootstrap /home/bootstrap/.ssh

if [ -n "${BOOTSTRAP_SSH_PUBKEY:-}" ]; then
  printf '%s\n' "${BOOTSTRAP_SSH_PUBKEY}" > /home/bootstrap/.ssh/authorized_keys
else
  echo "WARNING: BOOTSTRAP_SSH_PUBKEY is empty -- bootstrap user will have no way to log in." >&2
  : > /home/bootstrap/.ssh/authorized_keys
fi
chmod 600 /home/bootstrap/.ssh/authorized_keys
chown bootstrap:bootstrap /home/bootstrap/.ssh/authorized_keys

exec /usr/sbin/sshd -D -e
