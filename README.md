# AWS Terraform + Ansible Infrastructure Lab

This repository demonstrates a **production-grade AWS infrastructure pattern** built with **Terraform** and validated with **Ansible** using **SRE-style workflows**.

The goal is not simply to provision resources, but to model how real teams design, validate, and operate infrastructure:

- Clear separation of concerns (infra vs configuration)
- Secure-by-default networking
- Deterministic, testable automation
- Safe validation before mutation
- A clean Terraform → Ansible handoff

This mirrors how Terraform and Ansible are used together in production DevOps / SRE environments.

---

## Architecture Overview

The lab provisions a **two-tier AWS VPC architecture**:

- A **public subnet** containing a bastion host
- A **private subnet** containing internal workloads
- Outbound-only internet access from private resources via NAT
- No direct inbound access to private instances

### High-level traffic flow

```
Internet
   |
Internet Gateway
   |
Public Subnet
   |  (SSH from trusted IP only)
Bastion EC2
   |
   |  (SSH allowed only from bastion)
Private Subnet
   |
NAT Gateway
   |
Outbound Internet
```

**Architecture inspiration:**  
https://www.youtube.com/watch?v=2doSoMN2xvI&t=411s

---

## Terraform Design

Terraform is organized into **small, composable modules**, with a thin root module responsible only for wiring and variable assignment.

```
terraform-basic/
├── main.tf
├── variables.tf
├── provider.tf
└── terraform.tfvars.example

modules/
├── network/
│   ├── 01-vpc.tf
│   ├── 02-subnets.tf
│   ├── 03-route-tables.tf
│   ├── 04-igw.tf
│   ├── 05-public-route.tf
│   ├── 06-nat-gateway.tf
│   └── 07-private-route.tf
│
└── compute/
    ├── 08-ec2-public.tf
    └── 09-ec2-private.tf
```

### Network & Security Model

| Component | CIDR | Purpose |
|---------|------|---------|
| VPC | 10.0.0.0/16 | Isolated network |
| Public subnet | 10.0.1.0/24 | Bastion / NAT |
| Private subnet | 10.0.2.0/24 | Internal workloads |

- Public subnet routes to an Internet Gateway
- Private subnet routes to a NAT Gateway
- No inbound routes to private subnet
- SSH access restricted by security groups and source rules

---

## Ansible Integration

Ansible is used **after Terraform completes** to validate and manage the infrastructure.

### Goals

- Verify SSH access paths
- Prove bastion → private connectivity
- Validate NAT egress
- Demonstrate idempotent configuration changes
- Separate validation from mutation

---

## Repository Layout (Ansible)

```
ansible/
├── inventory/
│   ├── hosts.ini
│   └── generate_inventory.py
├── playbooks/
│   ├── hello.yml
│   └── site.yml
└── roles/

ansible.cfg
terraform-basic/tf-vpc-lab.pem
```

---

## How to Run This Lab

All commands are run from the **repository root** unless otherwise noted.

### 1. Provision infrastructure with Terraform

```
cd terraform-basic
terraform init
terraform apply
```

This creates:

- A VPC with public and private subnets
- A bastion EC2 instance with a public IP
- A private EC2 instance reachable only via bastion
- A NAT Gateway for private egress
- An SSH key written locally for Ansible access

---

### 2. Generate Ansible inventory from Terraform outputs

```
python3 ansible/inventory/generate_inventory.py
```

This produces:

```
ansible/inventory/hosts.ini
```

The inventory encodes:

- Direct SSH access to the bastion
- ProxyCommand-based SSH access to the private host via bastion
- Shared SSH identity and user configuration

---

### 3. Fix SSH key permissions

```
chmod 400 terraform-basic/tf-vpc-lab.pem
```

---

## Ansible Validation & Testing

### Connectivity checks (read-only)

```
ansible-playbook ansible/playbooks/hello.yml --tags connectivity
```

**Expected result**

- SSH succeeds to bastion and private host
- Hostnames and private IPs are printed
- No system changes are made

---

### NAT validation (private host only)

```
ansible-playbook ansible/playbooks/hello.yml --tags nat
```

**Expected result**

- Runs only on the private host
- Displays a public egress IP
- Confirms NAT Gateway outbound access

---

### Package installation (idempotent)

```
ansible-playbook ansible/playbooks/hello.yml --tags packages
```

**Expected result**

- `jq` installs on first run (changed=1)
- Subsequent runs are idempotent (changed=0)
- Package version is printed

---

### Combined validation

```
ansible-playbook ansible/playbooks/hello.yml --tags nat,packages
```

This represents a full private-host validation path:

- SSH → bastion → private
- NAT egress
- Controlled configuration change

---

### Optional ad-hoc connectivity checks

```
ansible -i ansible/inventory/hosts.ini public -m ping
ansible -i ansible/inventory/hosts.ini private -m ping -vv
```

---

## From Validation to Configuration

The `hello.yml` playbook is intentionally limited to **validation and proof-of-access**:

- SSH connectivity
- Bastion → private hop correctness
- NAT egress verification
- Safe, minimal package installation

Once these checks pass, the repository transitions to **real configuration management** via a standard Ansible entrypoint.

---

## Ansible Entry Point (`site.yml`)

`site.yml` is the canonical playbook for configuring hosts after validation.

It is designed to:

- Apply a **baseline role** to all hosts
- Apply role-specific configuration by inventory group
- Support selective runs via tags and limits

### Apply full configuration

```
ansible-playbook ansible/playbooks/site.yml
```

### Apply baseline only (safe, minimal)

```
ansible-playbook ansible/playbooks/site.yml --limit all --tags baseline
```

Use this when:

- Bootstrapping new instances
- Verifying baseline state
- Making low-risk changes (packages, users, hardening)

---

## Design Philosophy

This two-stage model mirrors real production workflows:

| Stage | Purpose |
|-----|--------|
| `hello.yml` | Validation, diagnostics, safe checks |
| `site.yml` | Declarative system configuration |

Key principles:

- Validation before mutation
- Tags control blast radius
- Inventory defines intent
- Roles express responsibility

This structure scales cleanly to:

- Multiple environments
- Additional roles (web, app, db)
- CI/CD pipelines
- SRE-style preflight checks

---

## Cleanup

When finished:

```
cd terraform-basic
terraform destroy
```

---

## Disclaimer

This repository is for learning and demonstration purposes.  
Always review AWS costs and security policies before applying infrastructure in real environments.
