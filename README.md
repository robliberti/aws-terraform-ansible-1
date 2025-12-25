# AWS Terraform + Ansible Infrastructure Lab

This repository demonstrates a **production-grade AWS infrastructure pattern** built with **Terraform** and validated with **Ansible** using **SRE-style workflows**.

The goal is not simply to provision resources, but to model how real teams design, validate, and operate infrastructure:

- Clear separation of concerns (infrastructure vs configuration)
- Secure-by-default networking
- Deterministic, testable automation
- Validation before mutation
- A clean Terraform → Ansible handoff
- Idempotent, repeatable execution

This mirrors how Terraform and Ansible are used together in real DevOps / SRE environments.

⸻

## Architecture Overview

The lab provisions a **two-tier AWS VPC architecture** with a **public reverse proxy** and a **private backend service**.

Key properties
	•	Public EC2 runs nginx as a reverse proxy
	•	Private EC2 runs a simple internal application (simpleapp)
	•	Private instance has no public IP
	•	All application traffic flows through the public host
	•	Private services are validated but never exposed directly

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
        +--------------------------------+
        |  Public EC2 (nginx + bastion)  |
        |  - SSH from trusted IP only    |
        |  - Reverse proxy (/app → 8080) |
        +--------------------------------+
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

⸻

Network & Security Model

Component	CIDR	Purpose
VPC	10.0.0.0/16	Isolated network
Public subnet	10.0.1.0/24	Reverse proxy / bastion
Private subnet	10.0.2.0/24	Internal workloads

Security guarantees:
	•	No inbound routing to the private subnet
	•	SSH to private host allowed only from the public host
	•	HTTP to public host restricted by CIDR
	•	Private app port never exposed publicly

⸻

Terraform Design

Terraform is organized into small, composable modules, with a thin root module responsible only for wiring and variables.

terraform-basic/
├── main.tf
├── variables.tf
├── terraform_basic_outputs.tf
└── terraform.tfvars.example

modules/
├── network/
│   ├── 01-vpc.tf
│   ├── 02-subnets.tf
│   ├── 03-route-tables.tf
│   ├── 04-igw.tf
│   ├── 05-public-default-route.tf
│   ├── 06-nat-gateway.tf
│   └── 07-private-default-route.tf
│
└── compute/
    ├── 08-ec2-public.tf
    ├── 09-ec2-private.tf
    ├── variables.tf
    └── outputs.tf

Terraform outputs provide:
	•	Public and private IPs
	•	Application port
	•	SSH key path

These outputs are consumed by Ansible inventory generation.

⸻

Ansible Integration

Ansible is used after Terraform completes to validate and manage the infrastructure.

Responsibilities
	•	Generate inventory deterministically from Terraform outputs
	•	Enforce secure SSH access paths
	•	Configure baseline OS settings
	•	Configure nginx reverse proxy
	•	Deploy a private backend application
	•	Validate application reachability and health

⸻

Repository Layout (Ansible)

ansible/
├── inventory/
│   ├── hosts.ini               # generated (not committed)
│   ├── generate_inventory.py
│   └── group_vars/
│       └── private.yml         # generated (not committed)
├── playbooks/
│   ├── hello.yml               # validation-only
│   └── site.yml                # authoritative configuration
└── roles/
    ├── baseline/
    ├── web/
    └── app/

ansible.cfg


⸻

## How to Run This Lab

All commands are run from the repository root.

⸻

### 1. Provision Infrastructure with Terraform

cd terraform-basic
terraform init
terraform plan
terraform apply

This creates:
	•	VPC with public and private subnets
	•	Public EC2 (reverse proxy / bastion)
	•	Private EC2 (internal application)
	•	NAT Gateway for private egress
	•	SSH key written locally for Ansible

⸻

### 2. Generate Ansible Inventory from Terraform Outputs

```
cd ..
python3 ansible/inventory/generate_inventory.py
cat ansible/inventory/hosts.ini
```

This generates:
	•	ansible/inventory/hosts.ini
	•	ansible/inventory/group_vars/private.yml

Both are intentionally not committed.> **Note:** If SSH fails due to key permission errors, ensure the private key has correct permissions:
>
> ```bash
> chmod 400 terraform-basic/tf-vpc-lab.pem
> ```

⸻

### 3. Apply Configuration + Validation (One Command)

```
ansible-playbook ansible/playbooks/site.yml --tags baseline,web,app,validate
```

This performs, in order:
	1.	Baseline OS configuration
	2.	nginx reverse proxy configuration
	3.	Private backend application deployment
	4.	Post-deploy health validation

## Ansible Validation (hello.yml)

⸻

Application & Health Checks

Internal application
	•	Runs on the private host
	•	Listens on port 8080
	•	Managed via systemd

Health endpoint
	•	Private backend:

http://<private_ip>:8080/healthz


	•	Public proxy (external):

http://<public_ip>/app/healthz



Expected response:

HTTP 200
ok

Validation is enforced via Ansible assertions.

⸻

### Validation Model

Post-deploy validation ensures:
	•	The private backend is reachable from the public host
	•	The health endpoint returns HTTP 200
	•	The response body matches expected content

If any check fails, the playbook exits with failure.

Validation is:
	•	Read-only
	•	Idempotent
	•	Explicitly ordered after deployment

⸻

## Continuous Integration (CI)

This repository includes a **GitHub Actions CI pipeline** that continuously validates
infrastructure and configuration code without touching live AWS resources.

The CI pipeline performs:

- Terraform formatting checks (`terraform fmt -check`)
- Terraform initialization and validation (`terraform init`, `terraform validate`)
- Non-blocking Terraform plan execution (safe without credentials)
- Ansible syntax validation for all playbooks (`site.yml`, `hello.yml`)

### CI Design Goals

- Catch errors before merge
- Enforce formatting and structure
- Avoid secrets or cloud credentials in CI
- Maintain a clean Terraform → Ansible handoff
- Mirror real SRE / Platform Engineering workflows

This ensures the repository remains **safe to apply**, **deterministic**, and
**reviewable** as it evolves.

⸻

### Cleanup

When finished:

cd terraform-basic
terraform destroy


⸻

### Design Philosophy

This project intentionally mirrors production workflows:

| Stage                | Purpose                     |
|----------------------|-----------------------------|
| Terraform            | Infrastructure provisioning |
| Inventory generation | Deterministic handoff       |
| Baseline             | OS consistency              |
| Web/App roles        | Declarative configuration   |
| Validation           | Enforced correctness        |

Key principles:
	•	Validation before mutation
	•	Tags limit blast radius
	•	Inventory defines intent
	•	Roles express responsibility
	•	Assertions enforce reality

⸻

### Disclaimer

This repository is for learning and demonstration purposes.
Always review AWS costs and security policies before applying infrastructure in real environments.

⸻

### Mindset

“I validate infrastructure changes with Terraform plans, regenerate inventory deterministically, verify connectivity before mutation, apply configuration through role-scoped Ansible runs, and enforce correctness with post-deploy assertions.”

⸻

Next Logical Upgrades

Each of these is interview-grade:
	•	Environment splits (dev/stage/prod)
	•	Replace bastion with ALB + private targets
	•	nginx hardening (TLS, headers, SELinux)
	•	Blue/green or canary backend deployment

# test CI