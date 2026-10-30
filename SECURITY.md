# Security

This repository holds a Terraform configuration that provisions one EC2 instance on AWS and runs a containerized Flask API on it. This document explains which security controls exist, what the CI scan does and does not check, and which gaps are known and accepted for a demo project.

## Reporting a vulnerability

Please do not open a public issue for a security problem. Use GitHub's private vulnerability reporting for this repository (Security tab, "Report a vulnerability"), or email mujahid249m@gmail.com. This is a learning project with no production users, so there is no formal response time, but reports are welcome.

## Controls in place

| Area | Control |
|---|---|
| Instance metadata | IMDSv2 is required (`http_tokens = "required"`), which closes the path from server-side request forgery to instance-credential theft. |
| Encryption at rest | The root EBS volume is encrypted. |
| Terraform state | State is remote in S3 instead of on a laptop. The bucket is encrypted, versioned, blocks all public access, and uses native S3 locking (`use_lockfile`) so concurrent runs cannot corrupt it. |
| Secrets | `app_api_key` is marked `sensitive`, so Terraform hides it from plan and apply output. The key is injected into the container at runtime and is never baked into an image. State files and the real `terraform.tfvars` are git-ignored, and the repository history contains no commit that touched them. |
| Container hardening | The container is started with `--read-only` and a tmpfs for `/tmp`, matching the application's own pipeline. |
| Access | The configuration was run with a dedicated IAM user, not the AWS root account. |
| AMI | The Ubuntu AMI is looked up dynamically, so the instance does not boot from a stale, unpatched image. |
| Provider versions | `.terraform.lock.hcl` is committed, so every machine uses the same provider build. |
| CI | Every push runs `terraform fmt -check`, `terraform validate`, and a Trivy configuration scan of the `.tf` files. The scan fails the build on HIGH or CRITICAL findings. These jobs use `terraform init -backend=false`, so they need no AWS credentials. Two scanner findings are suppressed by comments in `main.tf` (`AVD-AWS-0107` and `AVD-AWS-0104`), so a clean scan does not prove the network is locked down. See Known gaps. |
| Supply chain | Every GitHub Action in the workflow is pinned to a full commit SHA. `trivy-action` is pinned to the release that stayed safe after the March 2026 compromise of that action's tags. |
| Cost and cleanup | The default instance is Free Tier eligible, and `terraform destroy` was run and checked independently with the AWS CLI. |

## Mapping to the OWASP Top 10:2025

The OWASP Top 10 describes application risks, so most of it does not apply to infrastructure code. These are the categories this repository actually touches.

| Category | Status | Notes |
|---|---|---|
| A01 Broken Access Control (includes server-side request forgery) | Partly covered | IMDSv2 limits the damage of a request-forgery bug on the instance. SSH is open to the internet by default, so network access control is weak. |
| A02 Security Misconfiguration | Partly covered | Trivy checks the configuration in CI and the instance follows several hardening settings. The open SSH default and the open egress rule are known gaps. |
| A03 Software Supply Chain Failures | Partly covered | Actions are pinned to commit SHAs, and the provider lock file is committed. The application image is pulled from a public GHCR package by tag and is not verified by digest. |
| A04 Cryptographic Failures | Partly covered | The root volume and the state bucket are encrypted at rest. The instance serves plain HTTP with no TLS. |

## Known gaps

- SSH (port 22) is open to `0.0.0.0/0` by default so the demo works on first run. Set `allowed_ssh_cidr` to your own address in `terraform.tfvars` for anything beyond a disposable demo. The scanner finding for open ingress (`AVD-AWS-0107`) is suppressed by a comment in `main.tf`, so the CI scan does not flag it.
- The instance serves HTTP only. There is no load balancer and no certificate.
- Egress is open on purpose, because the instance must reach the internet to install Docker and pull the image. The scanner finding for it (`AVD-AWS-0104`) is suppressed by a comment in `main.tf`.
- The GHCR package is public so the instance can pull it without credentials. This is acceptable only because the image contains no sensitive data.
- The IAM user used to run the configuration has `AdministratorAccess`. It should be replaced with a least-privilege policy.
- `app_api_key` is passed to the instance through `user_data`. Terraform keeps sensitive values in state in plain text, and `user_data` can be read by anyone allowed to describe the instance. The encrypted, private state bucket reduces the risk, but a secrets store would remove it.
- The state bucket was created by hand and is not managed as code.
- The CI scan only reads the `.tf` files. It cannot see the running instance, and CI never runs `terraform plan` or `apply` against AWS.
- The full chain from code push to a live API was verified once by hand, not continuously.
- Pinned action SHAs are updated by hand until Dependabot is added.

## What I would improve next

- Replace the public GHCR package with an IAM instance role and scoped pull credentials.
- Move `API_KEY` into AWS Secrets Manager or SSM Parameter Store and let the instance fetch it at boot.
- Replace `AdministratorAccess` with a least-privilege policy.
- Restrict SSH by default, or remove it and use SSM Session Manager.
- Add an Application Load Balancer with an ACM certificate.
- Run `terraform plan` in CI through GitHub's OIDC integration, so no long-lived AWS keys are stored.
- Add Dependabot to keep the pinned action SHAs current.
