# AWS Terraform + Ansible Infrastructure Lab

This repository demonstrates a **production-grade AWS infrastructure pattern** built with **Terraform** and validated with **Ansible** using **SRE-style workflows**.

The goal is not simply to provision resources, but to model how real teams design, validate, and operate infrastructure:

- Clear separation of concerns (infrastructure vs configuration)
- Secure-by-default networking
- Deterministic, testable automation
- Validation before mutation
- A clean Terraform → Ansible handoff

This mirrors how Terraform and Ansible are used together in real DevOps / SRE environments.

---

## Architecture Overview

The lab provisions a **two-tier AWS VPC architecture**:

- Public subnet containing a bastion host
- Private subnet containing internal workloads
- Outbound-only internet access from private resources via NAT
- No direct inbound access to private instances

### High-level traffic flow

```
Internet
   |
Internet Gateway
   |
Public Subnet
   |  (SSH + HTTP from trusted IP only)
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

Terraform is organized into **small, composable modules**, with a thin root module responsible only for wiring and variables.

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
|----------|------|---------|
| VPC | 10.0.0.0/16 | Isolated network |
| Public subnet | 10.0.1.0/24 | Bastion / NAT |
| Private subnet | 10.0.2.0/24 | Internal workloads |

- Public subnet routes to an Internet Gateway
- Private subnet routes to a NAT Gateway
- No inbound routing to private subnet
- SSH and HTTP restricted by security groups

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
    ├── baseline/
    ├── web/
    └── app/

ansible.cfg
terraform-basic/tf-vpc-lab.pem
```

---

## How to Run This Lab (Step-by-Step)

All commands are run from the **repository root** unless otherwise noted.

---

### 1. Provision Infrastructure with Terraform

```
cd terraform-basic
terraform init
terraform plan
terraform apply
```

This creates:

- VPC with public and private subnets
- Bastion EC2 with public IP
- Private EC2 reachable only via bastion
- NAT Gateway for private egress
- SSH key written locally for Ansible

---

### 2. Generate Ansible Inventory from Terraform Outputs

```
cd ..
python3 ansible/inventory/generate_inventory.py
cat ansible/inventory/hosts.ini
```

The generated inventory encodes:

- Direct SSH access to the bastion
- ProxyCommand-based SSH to the private host
- Shared SSH user and identity

---

### 3. Fix SSH Key Permissions

```
chmod 400 terraform-basic/tf-vpc-lab.pem
```

---

## Ansible Validation (hello.yml)

`hello.yml` is intentionally **safe and validation-focused**.

---

### Connectivity Checks (Read-Only)

```
ansible-playbook ansible/playbooks/hello.yml --tags connectivity
```

Expected:
- SSH to bastion and private host succeeds
- Hostnames and private IPs displayed
- No changes made

---

### NAT Validation (Private Host Only)

```
ansible-playbook ansible/playbooks/hello.yml --tags nat
```

Expected:
- Runs only on private host
- Displays public egress IP
- Confirms NAT outbound access

---

### Package Validation (Idempotent)

```
ansible-playbook ansible/playbooks/hello.yml --tags packages
```

Expected:
- jq installs on first run
- Subsequent runs show no changes

---

### Combined Validation

```
ansible-playbook ansible/playbooks/hello.yml --tags nat,packages
```

---

### Optional Ad-Hoc Connectivity Checks

```
ansible -i ansible/inventory/hosts.ini public -m ping
ansible -i ansible/inventory/hosts.ini private -m ping -vv
```

---

## Configuration Management (site.yml)

Once validation passes, `site.yml` becomes the **authoritative configuration entry point**.

---

### Apply Baseline Configuration (Safe)

```
ansible-playbook ansible/playbooks/site.yml --tags baseline
```

Applies:
- Baseline packages
- Time sync (chrony)
- MOTD banner

---

### Apply Web Role (Public Host)

```
ansible-playbook ansible/playbooks/site.yml --tags web
```

Applies:
- nginx install and enablement
- Simple index page

Verify:
```
curl http://<public_ec2_ip>
```

---

### Apply App Role (Private Host)

```
ansible-playbook ansible/playbooks/site.yml --tags app
```

Applies:
- Simple internal application
- systemd-managed service

---

### Full Configuration Run

```
ansible-playbook ansible/playbooks/site.yml
```

---

### Dry-Run / Safety Check

```
ansible-playbook ansible/playbooks/site.yml --check --diff
```

Expected:
- Zero changes
- Confirms idempotency

---

## Cleanup

When finished:

```
cd terraform-basic
terraform destroy
```

---

## Design Philosophy

This project intentionally mirrors production workflows:

| Stage | Purpose |
|------|--------|
| Terraform | Infrastructure provisioning |
| hello.yml | Validation & diagnostics |
| site.yml | Declarative configuration |

Key principles:
- Validation before mutation
- Tags limit blast radius
- Inventory defines intent
- Roles express responsibility

---

## Disclaimer

This repository is for learning and demonstration purposes.  
Always review AWS costs and security policies before applying infrastructure in real environments.
