# Terraform AWS EC2 Demo

A minimal, reusable Terraform configuration that provisions a security-grouped
EC2 instance on AWS, boots it with a working web server via `user_data`, and
is fully parametrized through variables — no values are hardcoded into the
resource definitions.

Built as a hands-on companion to a [DevSecOps CI/CD Flask
project](https://github.com/M-249S/devops-cicd-project), practicing
Infrastructure as Code fundamentals: `plan` → `apply` → verify → `destroy`,
with real AWS resources and real cleanup discipline.

## What this creates

- One **security group** allowing SSH (port 22) and HTTP (port 80)
- One **EC2 instance** (Free Tier eligible `t3.micro` by default), running
  the latest official Ubuntu 22.04 AMI — looked up dynamically, never
  hardcoded, so it doesn't go stale
- A **`user_data` boot script** that installs nginx and serves a page
  confirming the instance was provisioned by Terraform, including the
  project name and boot timestamp

## Structure

| File | Purpose |
|---|---|
| `main.tf` | Provider config, AMI lookup, security group, EC2 instance |
| `variables.tf` | All configurable inputs, each with a description and a safe default |
| `outputs.tf` | Instance ID, public IP, and a ready-to-open test URL |
| `user_data.sh.tpl` | Boot script template, rendered with `templatefile()` |
| `terraform.tfvars.example` | Template for overriding defaults locally (never commit the real `terraform.tfvars`) |

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
# edit terraform.tfvars — e.g. change project_name, or restrict
# allowed_ssh_cidr to your own IP instead of 0.0.0.0/0
terraform plan
```

To actually provision (this creates real, billable — though Free Tier
eligible — AWS resources):

```bash
terraform apply
# wait ~30-60s after apply completes for user_data to finish running
# then open the printed test_url in a browser
```

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

## Security notes

- `allowed_ssh_cidr` defaults to `0.0.0.0/0` (open to the internet) for
  frictionless first-time use. For anything beyond a disposable demo,
  override it in `terraform.tfvars` with your own IP (`curl ifconfig.me`)
  in `/32` form.
- `.tfstate` files, `.tfvars` (the real one, not `.example`), and the
  `.terraform/` directory are all git-ignored — Terraform state can contain
  sensitive data and should never be committed.
- `.terraform.lock.hcl` **is** committed intentionally, so the AWS provider
  version stays consistent across machines (same principle as a
  `package-lock.json`).
- IAM access used to run this was a dedicated `terraform-user` with
  `AdministratorAccess`, not the AWS account's root user.

## What I'd add next

- Remote state (S3 backend + DynamoDB locking) instead of local `.tfstate`
- A `.github/workflows` CI job running `terraform fmt -check` and
  `terraform validate` on every push
- Connect this to the Flask project — provision infrastructure that
  actually pulls and runs the Docker image from GHCR instead of nginx
- Restrict the default security group's SSH rule rather than defaulting
  it open
