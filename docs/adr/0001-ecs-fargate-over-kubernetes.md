# ADR 0001: ECS Fargate with a managed database, not Kubernetes

- Status: accepted
- Date: 2026-11-22

## Context

The target is a team running one to a handful of containerised HTTP services with a relational
database. They need it secure and highly available in production, cheap in development, and operable
without a dedicated platform team. The usual options on AWS:

| Option | Strengths | Costs for this team |
|---|---|---|
| EKS (Kubernetes) | Portable workloads, rich ecosystem, best for many services and teams | Control-plane fee, node and add-on upgrades, cluster security (RBAC, admission, CNI), a platform skill set |
| ECS on Fargate | No nodes or control plane to run; IAM per task; native ALB, autoscaling and deployment rollback | AWS-specific API; fewer extension points; per-vCPU price above well-packed EC2 |
| ECS on EC2 / App Runner / Lambda | Lower unit cost (EC2), or simpler still (App Runner, Lambda) | Node patching (EC2); less network control (App Runner); request and runtime limits (Lambda) |

## Decision

Use **ECS on Fargate** behind an Application Load Balancer, with **RDS for PostgreSQL**. Keep each
concern in its own module with a narrow interface: network, service, database, deploy role and
budget. Promote the same code from dev to prod with variable files. Do not fork it.

Security decisions that follow:

- Tasks and the database live in private subnets; only the load balancer is public.
- No long-lived credentials anywhere. GitHub deploys through OIDC, the database master secret is
  generated and kept by RDS, and the application authenticates to PostgreSQL with IAM.
- One customer-managed KMS key per environment encrypts logs, database storage, Performance Insights,
  the master secret and container images.
- Deployments are guarded twice: the ECS circuit breaker rolls back failed releases, and Terraform
  ignores task-definition changes so an infrastructure apply never reverts an application release.

## Consequences

- Operating effort is mostly AWS-managed. There are no nodes to patch and no cluster to upgrade.
- Lock-in to ECS APIs is accepted. The application is still a standard OCI image, and moving to
  Kubernetes later means replacing the service module, not the application.
- Fargate's unit price is higher than well-packed EC2. At this scale the saved operating time
  outweighs it; revisit when steady-state compute dominates the bill.
- Testing uses `terraform test` with a mocked provider: fast, free and credential-less, but it proves
  configuration properties, not AWS behaviour. A real `plan` and `apply` against a sandbox account are
  still needed before production use.
