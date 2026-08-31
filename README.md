# Terraform AWS EC2 Demo

A reusable, security-conscious Terraform configuration that provisions an
EC2 instance on AWS and boots it running a real containerized application —
the Flask API from a [companion DevSecOps CI/CD
project](https://github.com/M-249S/devops-cicd-project), pulled live from
GitHub Container Registry.

This isn't two disconnected exercises. The full chain is proven to work
end-to-end: code push → CI/CD (lint, test, SAST, secret scan, dependency
scan) → Docker image published to GHCR → Terraform provisions AWS
infrastructure → the instance pulls and runs that exact image → the API
answers real requests on a public IP → `terraform destroy` tears it all
back down cleanly.

## What this creates

- One **security group** allowing SSH (port 22) and HTTP (port 80)
- One **EC2 instance** (Free Tier eligible `t3.micro` by default), running
  the latest official Ubuntu 22.04 AMI — looked up dynamically, never
  hardcoded, so it doesn't go stale
- A **`user_data` boot script** that installs Docker, then pulls and runs
  the Flask app image from GHCR — with the same hardening (`--read-only`,
  `--tmpfs /tmp`) used in that project's own local `docker-compose` setup,
  and the app's `API_KEY` injected at container runtime only, never baked
  into the image or written to disk

## Structure

| File | Purpose |
|---|---|
| `main.tf` | Provider config, AMI lookup, security group, EC2 instance |
| `variables.tf` | All configurable inputs, each with a description and a safe default |
| `outputs.tf` | Instance ID, public IP, and a ready-to-open test URL |
| `user_data.sh.tpl` | Boot script template, rendered with `templatefile()` |
| `terraform.tfvars.example` | Template for overriding defaults locally (never commit the real `terraform.tfvars`) |
| `.github/workflows/terraform.yml` | CI: format check, validate, and an IaC security scan — no AWS credentials required |

## Usage

```bash
terraform init
terraform fmt
terraform validate
terraform plan
```

To customize instead of using the defaults:

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars — e.g. change project_name, restrict
# allowed_ssh_cidr to your own IP, or point docker_image at a different tag
terraform plan
```

To actually provision (this creates real, billable — though Free Tier
eligible — AWS resources):

```bash
terraform apply
# wait ~60-90s after apply completes: the instance needs to boot, install
# Docker, pull the image from GHCR, and start the container
# then open the printed test_url in a browser
```

Once it's up, the same endpoints from the Flask project itself all work
against the live instance: `/`, `/health`, `/items`, `/metrics`,
`/config-status`.

**Always clean up after testing:**

```bash
terraform destroy
```

Verify destruction independently of Terraform's own output, e.g.:

```bash
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
  --output table
```

## CI

`.github/workflows/terraform.yml` runs on every push and pull request:

1. **Format & Validate** — `terraform fmt -check` and `terraform validate`.
   Deliberately uses `terraform init -backend=false`, so this stage needs
   **no AWS credentials at all** — it never talks to AWS.
2. **IaC Security Scan (Trivy)** — scans the `.tf` files themselves for
   misconfigurations before anything is ever provisioned.

## Security notes

- **IMDSv2 is required** (`http_tokens = "required"`) — closes a
  well-known path from SSRF to instance-credential theft via the metadata
  service.
- **Root EBS volume is encrypted at rest.**
- `allowed_ssh_cidr` defaults to `0.0.0.0/0` (open to the internet) for
  frictionless first-time use. For anything beyond a disposable demo,
  override it in `terraform.tfvars` with your own IP (`curl ifconfig.me`)
  in `/32` form.
- **Egress is intentionally open** — the instance needs outbound access to
  install Docker and pull the image from GHCR on boot. Documented and
  scanner-suppressed (`#trivy:ignore:AVD-AWS-0104`) rather than silently
  ignored.
- **The GHCR package is public**, so the instance can `docker pull` it
  with zero credentials. This is a deliberate trade-off for a demo project
  with no sensitive data in the image — in a real production setup, the
  instance would instead assume an IAM role and pull via AWS Secrets
  Manager or a private registry with scoped credentials.
- `.tfstate` files, `.tfvars` (the real one, not `.example`), and the
  `.terraform/` directory are all git-ignored — Terraform state can contain
  sensitive data and should never be committed.
- `.terraform.lock.hcl` **is** committed intentionally, so the AWS provider
  version stays consistent across machines (same principle as a
  `package-lock.json`).
- IAM access used to run this was a dedicated `terraform-user` with
  `AdministratorAccess`, not the AWS account's root user.
- `app_api_key` is marked `sensitive = true` — Terraform hides it (and, as
  a result, the entire rendered `user_data` script) from plan/apply output
  automatically.

## What I'd add next

- Remote state (S3 backend + DynamoDB locking) instead of local `.tfstate`
- Replace the public-GHCR-package approach with an IAM instance role +
  scoped pull credentials, closer to a real production pattern
- Pin `trivy-action` to a commit SHA instead of `@master` (same open item
  as the Flask project)
- An Application Load Balancer + ACM certificate instead of a bare HTTP
  instance, so the demo isn't served over plain HTTP
- Restrict the default security group's SSH rule rather than defaulting
  it open
