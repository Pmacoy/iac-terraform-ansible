# syntax=docker/dockerfile:1
#
# Stands in for a freshly-provisioned corporate EC2 instance: nothing
# configured yet except SSH access, which is the one thing Ansible needs to
# take over from here. Everything ansible/roles/*/tasks/main.yml does --
# creating the app user, hardening sshd, installing nginx -- happens
# against a container built from exactly this image, not a pre-baked one,
# so the demo proves configuration management, not a lucky base image.
FROM ubuntu:26.04

# Not pinning apt package versions here on purpose: this base image is
# itself repinned by Dependabot (docker ecosystem, docker/corporate-server)
# whenever Ubuntu 24.04 moves, and hard-coding e.g. openssh-server's exact
# version would silently start failing every time Ubuntu ships a security
# update for it -- the opposite of what a security-conscious pin should do.
#
# Also deliberately NOT deleting /var/lib/apt/lists/* afterward, even
# though that's the standard image-slimming move hadolint's DL3009 wants.
# These containers are configured live by Ansible after boot (roles/
# baseline and roles/webserver install more packages later), and Ansible's
# apt module relies on cache_valid_time to skip a redundant apt-get update
# and stay idempotent -- but cache_valid_time only checks the cache's
# *age*, not whether an index is actually present. Wipe the lists here and
# a fresh container has a cache that *looks* fresh (recent mtime) but is
# empty, so cache_valid_time tells Ansible to trust it, and the very next
# apt-get install fails with "No package matching '<pkg>' is available".
# Keeping the lists costs a bit of image size in exchange for both this
# RUN and Ansible's apt module (later) actually working.
# hadolint ignore=DL3008,DL3009
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      openssh-server \
      sudo \
      python3 \
      python3-apt \
      iproute2

# Ansible's default connection needs a Python interpreter on the target --
# python3 above is it; no extra ansible-specific packaging required.

RUN mkdir -p /run/sshd

# A single bootstrap user for Ansible to connect as. Its authorized key is
# injected at *container start*, not baked in here -- see entrypoint.sh and
# docker-compose.yml. sshd otherwise starts with Ubuntu's stock defaults
# (password auth on, root login left at its distro default). That's the
# "before" state on purpose: ansible/roles/ssh_hardening is what locks it
# down for real (key-only auth, explicit root deny, a hardened cipher/MAC
# list), so the demo proves configuration management fixed something,
# rather than starting from an already-hardened image.
RUN useradd --create-home --shell /bin/bash --groups sudo bootstrap && \
    echo "bootstrap ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/bootstrap && \
    chmod 0440 /etc/sudoers.d/bootstrap

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
