# AWS Terraform + Ansible Infrastructure Lab

This repository demonstrates a **production-grade AWS infrastructure pattern** built with **Terraform**, and validated with **Ansible** using **SRE-style workflows**.

The focus is not “getting something working,” but modeling:

- Clean separation of concerns
- Secure-by-default network design
- Deterministic, testable automation
- Clear handoff between infrastructure and configuration layers

This mirrors how real teams structure Terraform + Ansible in practice.

---

## Architecture Overview

The lab provisions a **two-tier VPC architecture**:

- Public subnet with tightly scoped inbound access
- Private subnet with outbound-only internet access via NAT
- No direct inbound access to private resources
- Explicit bastion → private access path

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

---

## Terraform Design

Terraform is split into **small, composable modules**, with a thin root module responsible only for wiring and configuration.

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

---

## Network & Security Model

| Component | CIDR | Purpose |
|--------|------|---------|
| VPC | 10.0.0.0/16 | Isolated network |
| Public subnet | 10.0.1.0/24 | Bastion / NAT |
| Private subnet | 10.0.2.0/24 | Internal workloads |

- Public subnet routes to Internet Gateway
- Private subnet routes to NAT Gateway
- No inbound routing to private subnet

---

## Ansible Integration

Ansible is used **after Terraform completes** to validate and manage the infrastructure.

### Goals

- Verify SSH access paths
- Prove NAT egress works
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
│   └── hello.yml
└── roles/

ansible.cfg
terraform-basic/tf-vpc-lab.pem
```

---

## Usage

### Apply Terraform

```
cd terraform-basic
terraform init
terraform apply
```

### Generate inventory

```
python3 ansible/inventory/generate_inventory.py
```

### Fix SSH key permissions

```
chmod 400 terraform-basic/tf-vpc-lab.pem
```

---

## Ansible Validation

### Connectivity (read-only)

```
ansible-playbook ansible/playbooks/hello.yml --tags connectivity
```

### NAT validation

```
ansible-playbook ansible/playbooks/hello.yml --tags nat
```

### Package installation (idempotent)

```
ansible-playbook ansible/playbooks/hello.yml --tags packages
```

### Combined validation

```
ansible-playbook ansible/playbooks/hello.yml --tags nat,packages
```

---

## Why This Matters

This lab demonstrates:

- Real AWS isolation patterns
- Secure bastion-based access
- Terraform-to-Ansible handoff
- Tag-driven, operator-safe automation

This is a strong baseline for production infrastructure work.

---

## Disclaimer

This repository is for learning and demonstration purposes. Always review AWS costs and security policies before applying infrastructure in real environments.
