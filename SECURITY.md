# Security Policy

This is a portfolio/demo project, not a production system, but it's built
and scanned the way a real one would be.

## Automated scanning

Every push and pull request runs:

- **gitleaks** -- secret scanning across the full git history
- **hadolint** -- Dockerfile linting, including security-relevant checks
  (running as non-root, pinned base images, no unnecessary layers)
- **tfsec** and **Checkov** -- static analysis of the Terraform config
  (public access blocks, encryption, IAM least privilege, security group
  ingress rules)
- **ansible-lint** (security profile) -- flags risky Ansible patterns
  (e.g. `no_log` missing on tasks that could leak secrets, unpinned
  package versions, overly-permissive file modes)
- **Trivy** filesystem scan -- known-vulnerability scanning across
  dependencies and IaC files
- **GitHub Dependency review** -- flags newly-introduced vulnerable or
  license-incompatible dependencies on every pull request

See `.github/workflows/security.yml` for the exact jobs.

## Reporting a vulnerability

If you find a real security issue in this repository's code or workflows
(not in Terraform/Ansible/Docker themselves), please open a
[GitHub Security Advisory](../../security/advisories/new) rather than a
public issue, so it can be addressed before disclosure.

## Scope notes

- Terraform in this repo targets [LocalStack](https://localstack.cloud/),
  not real AWS -- there are no real cloud credentials anywhere in this
  repository or its CI configuration.
- The Ansible "fleet" is a pair of disposable Docker containers, not real
  servers. The SSH keypair used to reach them is generated fresh by
  `scripts/generate-ssh-key.sh` on every run (local or CI) and is never
  committed.
