# AWS Terraform + Ansible Learning Lab

This repository is a structured learning project that demonstrates how to build a **real-world AWS network and compute architecture using Terraform**, with a clear path toward **Ansible-based configuration management** and **SRE-style automation**.

The goal is not just to create infrastructure, but to model **clean separation of concerns**, **secure defaults**, and **scalable patterns** commonly used in production environments.

---

## Architecture Overview

This project builds a **two-tier AWS VPC architecture**:

- A **public subnet** with controlled inbound access
- A **private subnet** with outbound-only internet access via NAT
- Infrastructure defined entirely in Terraform modules
- Configuration and lifecycle control designed to integrate cleanly with Ansible

### High-level flow

```
Internet
   |
Internet Gateway
   |
Public Subnet
   |  (SSH from trusted IP only)
Public EC2 Instance
   |
   |  (SSH allowed only from public instance)
Private Subnet
   |
NAT Gateway
   |
Outbound Internet (updates, package installs, etc.)
```

---

## Terraform Structure

Terraform is split into **reusable modules**, with a thin root configuration responsible for wiring and variable assignment.

```
.
├── terraform-basic/        # Root module (entry point)
│   ├── main.tf             # Module composition
│   ├── variables.tf        # Root-level variables
│   ├── terraform.tfvars.example
│   └── provider.tf
│
├── modules/
│   ├── network/            # VPC, subnets, routing, IGW, NAT
│   │   ├── 01-vpc.tf
│   │   ├── 02-subnets.tf
│   │   ├── 03-route-tables.tf
│   │   ├── 04-igw.tf
│   │   ├── 05-public-default-route.tf
│   │   ├── 06-nat-gateway.tf
│   │   ├── 07-private-default-route.tf
│   │   └── variables.tf
│   │
│   └── compute/            # EC2, security groups, SSH keys
│       ├── 08-ec2-public.tf
│       ├── 09-ec2-private.tf
│       └── variables.tf
│
├── ansible/                # Future configuration management
│   ├── inventory/
│   │   └── README.md
│   ├── playbooks/
│   └── roles/
│
└── docs/
```

---

## Network Design

### VPC

- CIDR: `10.0.0.0/16`
- DNS hostnames and resolution enabled

### Subnets

| Subnet  | CIDR          | Purpose               |
| ------- | ------------- | --------------------- |
| Public  | `10.0.1.0/24` | Bastion / entry point |
| Private | `10.0.2.0/24` | Internal workloads    |

### Routing

- **Public route table**
  - `0.0.0.0/0 → Internet Gateway`
- **Private route table**
  - `0.0.0.0/0 → NAT Gateway`
- No inbound routes to private subnet

### NAT Gateway

- Deployed in the **public subnet**
- Uses an Elastic IP
- Enables outbound internet access for private instances without exposing them

---

## Compute Design

### Public Instance

- Amazon Linux
- Public IP assigned
- SSH allowed **only from a single trusted CIDR**
- Acts as a controlled jump host

### Private Instance

- No public IP
- SSH allowed **only from the public instance**
- Internet access via NAT Gateway
- Ideal target for Ansible-managed configuration

---

## Security Principles Demonstrated

- Least-privilege network access
- No inbound access to private resources
- SSH restricted by:
  - Source IP (public)
  - Security group reference (private)
- No secrets committed to version control
- Terraform state and keys ignored via `.gitignore`

---

## Ansible Integration (Planned)

This repository is intentionally structured to support Ansible in progressive stages:

1. **terraform-basic**
   - Infrastructure only
2. **terraform-ansible-simple**
   - Terraform outputs → static Ansible inventory
   - Basic configuration (packages, users)
3. **terraform-ansible-sre**
   - Dynamic inventory
   - Idempotent roles
   - Health checks and validation
   - Production-style workflows

---

## Usage (Terraform)

From the root Terraform directory:

```bash
cd terraform-basic
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Destroy when finished:

```bash
terraform destroy
```

---

## Learning Objectives

This project is designed to reinforce:

- Modular Terraform design
- AWS networking fundamentals
- NAT vs IGW behavior
- Secure SSH patterns
- Clean handoff between Terraform and Ansible
- Repo hygiene suitable for real teams

---

## Future Enhancements

- Dynamic Ansible inventory from Terraform outputs
- GitHub Actions for `plan` and `apply`
- Remote Terraform state backend
- Multi-AZ support
- Load balancer integration
- SRE-style runbooks and alerts

---

## Disclaimer

This repository is for learning and experimentation. Always review AWS costs before applying infrastructure in real accounts.

