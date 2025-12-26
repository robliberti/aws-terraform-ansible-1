# AWS Terraform + Ansible Infrastructure Lab

This repository demonstrates a **production-grade AWS infrastructure pattern** built with **Terraform** and validated with **Ansible**, following **SRE-style workflows**.

The goal is not simply to provision resources, but to model how real teams design, validate, and operate infrastructure:

- Clear separation of concerns (infrastructure vs configuration)
- Secure-by-default networking
- Deterministic, testable automation
- Validation before mutation
- A clean Terraform → Ansible handoff
- Idempotent, repeatable execution

This mirrors how Terraform and Ansible are used together in real DevOps / SRE environments.

---

## Architecture Overview

The lab provisions a **two-tier AWS VPC architecture** with a **public reverse proxy** and a **private backend service**.

Key properties:
- Public EC2 runs nginx as a reverse proxy
- Private EC2 runs a simple internal application (`simpleapp`)
- Private instance has **no public IP**
- All application traffic flows through the public host
- Private services are validated but never exposed directly

### High-level traffic flow

```
                   Internet
                      |
                      |  HTTP/80 (restricted by security group)
                      v
                Internet Gateway
                      |
                Public Subnet
                      |
        +--------------------------------------------+
        |  Public EC2 (nginx reverse proxy + bastion) |
        |  - SSH from trusted IP only                 |
        |  - Reverse proxy (/app → 8080)              |
        +--------------------------------------------+
                      |
                      |  SSH (22) and HTTP (8080)
                      |  allowed only from public SG
                      v
                Private Subnet
                      |
        +--------------------------------+
        |   Private EC2 (simpleapp)      |
        |   - No public IP               |
        |   - Listens on :8080           |
        |   - /healthz endpoint          |
        +--------------------------------+
                      |
                      |  Outbound-only traffic
                      v
                NAT Gateway
                      |
                   Internet
```

**Architecture inspiration:**  
https://www.youtube.com/watch?v=2doSoMN2xvI&t=411s

Outbound-only internet access from the private subnet is provided via a NAT Gateway.

---

## Network & Security Model

| Component       | CIDR           | Purpose              |
|-----------------|----------------|----------------------|
| VPC             | 10.0.0.0/16    | Isolated network     |
| Public subnet   | 10.0.1.0/24    | Reverse proxy / SSH  |
| Private subnet  | 10.0.2.0/24    | Internal workloads   |

Security guarantees:
- No inbound routing to the private subnet
- SSH to private host allowed **only from the public host**
- HTTP to public host restricted by CIDR
- Private app port never exposed publicly

---

## Terraform Design (Environment-Based)

Terraform is **environment-scoped**, not monolithic.

Each environment is isolated with its own state, variables, and outputs:

```
terraform/
└── envs/
    ├── dev/
    ├── stage/
    └── prod/
```

Terraform is organized into composable modules:

```
modules/
├── network/
│   ├── vpc, subnets, routes, igw, nat
└── compute/
    ├── public EC2
    ├── private EC2
    ├── security groups
```

Each environment exposes outputs required by Ansible:
- Public instance public IP
- Public instance private IP
- Private instance private IP
- Application port
- SSH private key path

These outputs are consumed **deterministically** by Ansible inventory generation.

---

## Ansible Integration

Ansible runs **after Terraform completes** and is responsible for:

- Inventory generation from Terraform outputs
- Secure SSH access paths
- Baseline OS configuration
- nginx reverse proxy configuration
- Private backend application deployment
- Post-deploy validation and health checks

Ansible never guesses infrastructure — it **reads Terraform state**.

`generate_inventory.py` reads Terraform outputs for the selected environment and emits an Ansible inventory and group variables without hardcoding IPs or hostnames.

---

## Repository Layout (Ansible)

```
ansible/
├── inventory/
│   ├── envs/
│   │   ├── dev/
│   │   ├── stage/
│   │   └── prod/
│   └── generate_inventory.py
├── playbooks/
│   ├── hello.yml        # validation-only
│   └── site.yml         # authoritative config
└── roles/
    ├── baseline/
    ├── web/
    └── app/
```

Generated files are intentionally **not committed**.

---

## How to Run This Lab

All commands are run from the repository root.

All commands are shown explicitly to mirror real operational workflows and to make validation steps auditable and repeatable.

---

## 1. Provision Infrastructure (per environment)

> Note: Public IP values may change on every `terraform apply`.

First, determine your current public IP (used for SG restrictions):

```bash
curl checkip.amazonaws.com
```

Update the `allowed_cidr` variable in each environment’s tfvars file to your current public IP using /32 CIDR notation:

```hcl
allowed_cidr = "X.X.X.X/32"
```

Files to update:
- terraform/envs/dev/dev.tfvars
- terraform/envs/stage/stage.tfvars
- terraform/envs/prod/prod.tfvars

### DEV

```bash
terraform -chdir=terraform/envs/dev init
terraform -chdir=terraform/envs/dev apply
```

### STAGE

```bash
terraform -chdir=terraform/envs/stage init
terraform -chdir=terraform/envs/stage apply
```

### PROD

```bash
terraform -chdir=terraform/envs/prod init
terraform -chdir=terraform/envs/prod apply
```

Verify outputs:

```bash
terraform -chdir=terraform/envs/dev output public_instance_public_ip
terraform -chdir=terraform/envs/stage output public_instance_public_ip
terraform -chdir=terraform/envs/prod output public_instance_public_ip
```

---

## 2. Generate Ansible Inventory (per environment)

```bash
python3 ansible/inventory/generate_inventory.py dev
python3 ansible/inventory/generate_inventory.py stage
python3 ansible/inventory/generate_inventory.py prod
```

Validate connectivity:

```bash
ansible -i ansible/inventory/envs/dev/hosts.ini   public  -m ping
ansible -i ansible/inventory/envs/dev/hosts.ini   private -m ping

ansible -i ansible/inventory/envs/stage/hosts.ini public  -m ping
ansible -i ansible/inventory/envs/stage/hosts.ini private -m ping

ansible -i ansible/inventory/envs/prod/hosts.ini  public  -m ping
ansible -i ansible/inventory/envs/prod/hosts.ini  private -m ping
```

---

## 3. Apply Configuration + Validation

```bash
ansible-playbook -i ansible/inventory/envs/dev/hosts.ini   ansible/playbooks/site.yml --tags baseline,web,app,validate
ansible-playbook -i ansible/inventory/envs/stage/hosts.ini ansible/playbooks/site.yml --tags baseline,web,app,validate
ansible-playbook -i ansible/inventory/envs/prod/hosts.ini  ansible/playbooks/site.yml --tags baseline,web,app,validate
```

---

> Note: Public IPs are assigned dynamically by AWS and will change after each `terraform destroy` / `terraform apply`. Always retrieve the current value using `terraform output` before running curl checks.

## Runtime Validation (External)

### Host identity for each environment

```bash
curl http://<PUBLIC_IP>/app/ | grep hostname
```

### Health checks for each environment

```bash
curl -sS -i http://<PUBLIC_IP>/app/healthz | head
```

Expected:
```
HTTP/1.1 200 OK
ok
```

---

## Dry Run / Idempotency Validation

```bash
ansible-playbook -i ansible/inventory/envs/dev/hosts.ini   ansible/playbooks/site.yml --check --diff --tags baseline,web,app,validate
ansible-playbook -i ansible/inventory/envs/stage/hosts.ini ansible/playbooks/site.yml --check --diff --tags baseline,web,app,validate
```

---

## Cleanup

Destroy **only the environment you intend**:

```bash
terraform -chdir=terraform/envs/dev destroy
terraform -chdir=terraform/envs/stage destroy
terraform -chdir=terraform/envs/prod destroy
```

---

## Troubleshooting & Diagnostics

Direct SSH access is not required for normal operation. Use the commands below only for debugging.

SSH to the public host (bastion):

```bash
ssh -i terraform/envs/dev/tf-vpc-lab-dev.pem ec2-user@<public_ip>
```

> SSH key paths are environment-specific (`tf-vpc-lab-<env>.pem`).

SSH to the private host (via bastion):

```bash
ssh -i terraform/envs/dev/tf-vpc-lab-dev.pem \
  -o ProxyCommand="ssh -W %h:%p ec2-user@<public_ip>" \
  ec2-user@<private_ip>
```

These commands mirror the SSH path used internally by Ansible.

Direct SSH is intentionally minimized. All configuration and validation is expected to be performed via Ansible and HTTP health checks.

> Tip: If SSH stops working unexpectedly, re-run `curl checkip.amazonaws.com` and confirm the value still matches your `*.tfvars` files.

---

## Optional: Makefile Convenience Wrapper

A `Makefile` is provided in the repository root to wrap the exact commands shown below into repeatable, environment-scoped targets.

The Makefile:
- Does NOT introduce new behavior
- Does NOT hide Terraform or Ansible commands
- Exists only to reduce typing and prevent mistakes

All targets map 1:1 to the commands documented in this README.

Examples:

```bash
make ip
make dev-apply
make dev-inv
make dev-ping
make dev-ansible
make dev-health
make dev-check
```

Production safety guard:

```bash
make prod-apply CONFIRM=YES
make prod-destroy CONFIRM=YES
```

---

## Design Philosophy

| Stage                | Purpose                     |
|----------------------|-----------------------------|
| Terraform            | Infrastructure provisioning |
| Inventory generation | Deterministic handoff       |
| Baseline             | OS consistency              |
| Web/App roles        | Declarative configuration   |
| Validation           | Enforced correctness        |

Key principles:
- Validation before mutation
- Tags limit blast radius
- Inventory defines intent
- Roles express responsibility
- Assertions enforce reality

---

## Next Logical Upgrades

Interview-grade extensions:
- Environment safety rails (explicit prod confirmations for `terraform/envs/prod` + prod Ansible inventory)
- ALB replacing public EC2/nginx (ALB → private targets, per-environment naming)
- TLS hardening (either ALB-terminated TLS or nginx TLS + headers)
- Canary or blue/green backend deployments (target groups or multiple private backends)
- CI policy gates on prod changes (protect `terraform/envs/prod/**`)
- Cost controls (auto-expire `terraform/envs/dev`)
- Repo hygiene (remove stale references to deleted Terraform roots; keep scripts/docs aligned to `terraform/envs/<env>`)