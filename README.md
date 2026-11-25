# cloud-native-reference-aws

[![ci](https://github.com/md-rubbaite/cloud-native-reference-aws/actions/workflows/ci.yml/badge.svg)](https://github.com/md-rubbaite/cloud-native-reference-aws/actions/workflows/ci.yml)
![terraform](https://img.shields.io/badge/terraform-%E2%89%A5%201.10-7B42BC)
![aws provider](https://img.shields.io/badge/aws%20provider-6.x-FF9900)
![license](https://img.shields.io/badge/license-MIT-green)

**A production-shaped AWS baseline for a containerised API, in Terraform: private by default, no
long-lived keys, no database password in state, a budget alarm from day one. The security
properties are tested in CI without an AWS account.**

## The problem

Most teams' first AWS stack grows from a tutorial. The database ends up public "temporarily", a CI
user with static access keys deploys everything, passwords sit in Terraform state, and the first cost
alert is the invoice. Fixing that later means downtime and migrations. This repository is the version
built the other way round, small enough to read in an afternoon.

## What you get

```text
                 Internet
                    │ 443 (80 → 301 to 443)
        ┌───────────▼────────────┐   public subnets (one per AZ)
        │ Application Load       │   TLS 1.3 policy, invalid headers dropped
        │ Balancer               │
        └───────────┬────────────┘
                    │ container port, from the ALB security group only
        ┌───────────▼────────────┐   private subnets, no public IPs
        │ ECS Fargate service    │   read-only root FS, circuit-breaker rollback,
        │ (ARM64, autoscaling)   │   CPU target tracking
        └───────────┬────────────┘
                    │ 5432, IAM auth + TLS, from the task security group only
        ┌───────────▼────────────┐
        │ RDS PostgreSQL 17      │   encrypted (CMK), Multi-AZ in prod, managed master
        └────────────────────────┘   secret, Performance Insights, enhanced monitoring

  GitHub Actions ──OIDC──▶ deploy role (one repo, explicit refs) ──▶ ECR push + ECS update
  KMS key (rotating) encrypts logs, database, secrets and images · AWS Budget alerts at 80% / 100% forecast
  VPC flow logs (1 year) · S3 gateway endpoint · default security group locked
```

| Module | Purpose |
|---|---|
| [`network`](modules/network) | VPC across 2–3 AZs; public subnets only for the load balancer; one shared NAT gateway (dev) or one per AZ (prod); S3 gateway endpoint; flow logs |
| [`service`](modules/service) | ECS Fargate behind an ALB; HTTPS with HTTP redirect; private tasks; autoscaling; rollback on failed deployments |
| [`database`](modules/database) | RDS PostgreSQL; TLS enforced; IAM database authentication; RDS-managed master secret; backups 7–35 days |
| [`github_oidc`](modules/github_oidc) | Deploy role assumable only by named refs of one repository; can push one ECR repository and roll one ECS service |
| [`budget`](modules/budget) | Monthly budget filtered on the `Project` tag; alerts on actual and forecast spend |

The root module composes them with one customer-managed KMS key and an immutable, scan-on-push ECR
repository. Every resource is tagged `Project`, `Environment`, `Owner` and `ManagedBy` through
`default_tags`, which is also what the budget filters on.

## Dev and prod from the same code

| Setting | `dev.tfvars` | `prod.tfvars` |
|---|---|---|
| Availability zones | 2 | 3 |
| NAT gateways | 1 shared | 1 per AZ |
| Database | single-AZ `db.t4g.micro`, 7-day backups | Multi-AZ `db.m7g.large`, 30-day backups |
| Deletion protection | off | **required** (the plan fails without it) |
| Tasks | 1–3 | 2–12 |
| Image reference | unique tag | digest |

## Usage

```bash
# one-time: an S3 bucket for state (versioned, encrypted); locking uses S3 lock files, no DynamoDB table
terraform init -backend-config=environments/dev.s3.tfbackend
terraform plan -var-file=environments/dev.tfvars -out=dev.tfplan
terraform apply dev.tfplan
```

Then create the application database user once (as the master user, from a bastion or a one-off task):

```sql
CREATE USER app WITH LOGIN;
GRANT rds_iam TO app;
```

The application connects as `app` with an IAM authentication token; the task role already holds
`rds-db:connect` for that user only. Deployments run from GitHub with
[`examples/deploy-workflow.yml`](examples/deploy-workflow.yml): build, push by digest, render the task
definition and wait for the service to stabilise. Terraform ignores later task-definition changes, so
infrastructure applies never roll back an application release.

## Tested without an AWS account

`terraform test` plans every module against a **mocked AWS provider**. 51 assertions in 27 test runs
check the properties that matter, including:

- the database is not public, is encrypted with the CMK, forces TLS, uses IAM authentication and lets RDS manage the master password; only the task security group reaches 5432
- tasks have no public IP, run in private subnets, accept traffic only from the load balancer, and run read-only and unprivileged
- the HTTPS listener uses a TLS 1.3 policy, port 80 only redirects, and invalid headers are dropped
- the deploy role trusts exactly `repo:<owner>/<repo>:ref:<ref>` for listed refs; only the two actions without resource-level permissions use `*`; `iam:PassRole` is limited to ECS tasks
- dev plans one NAT gateway, prod three; prod refuses a database without deletion protection
- invalid input is rejected: one AZ, a VPC smaller than /16, `:latest` images, wildcard repositories or refs, backups under 7 days, bad alert emails

CI also runs `terraform fmt -check`, `terraform validate` and [checkov](https://www.checkov.io/), which
must report no unskipped findings. The seven skips are inline, each with its reason (for example, the
`ecr:GetAuthorizationToken` wildcard that AWS requires).

## Cost notes

The largest fixed cost in a small environment is usually NAT gateways, which are billed per hour and
per GB processed. This is why dev shares one and prod pays for one per AZ to survive an AZ outage. The
S3 gateway endpoint is free and keeps image-layer downloads off NAT. Multi-AZ doubles database instance
cost. Check current prices in the [AWS Pricing Calculator](https://calculator.aws/) for your region before
choosing sizes; the budget alarm is there because estimates are wrong.

## Design decisions

- [ADR 0001: ECS Fargate with a managed database, not Kubernetes](docs/adr/0001-ecs-fargate-over-kubernetes.md)
- No secrets in Terraform: RDS generates and stores the master password; the app uses IAM auth.
- Fixed costs are visible and switchable (`single_nat_gateway`, `db_multi_az`), not hidden in modules.

## Scope and limits

This is a reference, not a landing zone. Not included: AWS Organizations, SCPs and account vending;
WAF rules (attach a web ACL to the load balancer); ALB access logs (set `access_logs_bucket`); a bastion
or SSM-based database access path; backups to a second region; DNS and the ACM certificate itself. Read
`readonlyRootFilesystem` before deploying: applications that write to disk need a mounted volume or
`/tmp` scratch space.

---

Author: [Rubbaite T. Hassain](https://tanvir.info.bd) ([LinkedIn](https://www.linkedin.com/in/rubbaite)) · Software Architect, Founder of [Datazo InfoTech](https://www.datazoinfotech.com.bd) · MIT License

Architecture, requirements and review by Rubbaite T. Hassain; implementation AI-assisted.
