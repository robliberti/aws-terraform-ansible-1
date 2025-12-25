Validation & Diagnostics (hello.yml)

This document describes the read-only validation and diagnostic workflows provided by hello.yml.

These checks are intentionally non-destructive and safe to run at any time. They are designed for:
	•	Learning and exploration
	•	Troubleshooting connectivity issues
	•	Validating network paths before deployment
	•	Demonstrating validation-before-mutation workflows

Note: The authoritative deployment and enforced post-deploy validation live in site.yml.
This file documents diagnostics, not configuration management.

⸻

Purpose of hello.yml

hello.yml exists to model how engineers validate infrastructure without changing system state.

It demonstrates:
	•	Bastion-based SSH access patterns
	•	Private subnet isolation
	•	NAT egress behavior
	•	Idempotent package operations
	•	Use of tags to limit blast radius

⸻

Connectivity Checks (Read-Only)

ansible-playbook ansible/playbooks/hello.yml --tags connectivity

Validates:
	•	SSH access to the public host
	•	SSH access to the private host via ProxyCommand
	•	Inventory correctness

Expected behavior:
	•	Hostnames and private IPs are displayed
	•	No changes are made to either host

⸻

NAT Egress Validation (Private Host Only)

ansible-playbook ansible/playbooks/hello.yml --tags nat

Validates:
	•	Outbound internet access from the private subnet
	•	NAT Gateway routing correctness

Expected behavior:
	•	Runs only on the private host
	•	Displays the observed public egress IP

⸻

Package Validation (Idempotency)

ansible-playbook ansible/playbooks/hello.yml --tags packages

Validates:
	•	Package installation behavior
	•	Idempotency guarantees

Expected behavior:
	•	Packages install on first run
	•	Subsequent runs report no changes

⸻

Combined Diagnostics

ansible-playbook ansible/playbooks/hello.yml --tags nat,packages

Runs multiple diagnostic checks in a single invocation.

⸻

Optional Ad-Hoc Connectivity Checks

ansible -i ansible/inventory/hosts.ini public -m ping
ansible -i ansible/inventory/hosts.ini private -m ping -vv

Useful for:
	•	Debugging SSH failures
	•	Verifying inventory paths
	•	Manual inspection during development

⸻

Relationship to site.yml

File	    Responsibility
hello.yml	Diagnostics & validation (read-only)
site.yml	Configuration management & enforced validation

In production environments:
	•	Diagnostics may be run manually or during investigation
	•	site.yml is the authoritative source of desired state

⸻

Why This Exists

Separating diagnostics from configuration:
	•	Reduces blast radius
	•	Improves operator confidence
	•	Encourages validation before mutation
	•	Mirrors real SRE / platform workflows

This separation is intentional and instructional.
