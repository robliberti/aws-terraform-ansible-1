# Makefile - AWS Terraform + Ansible Infrastructure Lab
#
# Convenience wrapper around the exact commands documented in README.md.
# Targets are environment-scoped (dev|stage|prod) and intentionally explicit.
#
# Usage examples:
#   make ip
#   make dev-apply
#   make dev-inv
#   make dev-ping
#   make dev-ansible
#   make dev-validate
#   make dev-health
#   make dev-check
#   make dev-destroy
#
# Generic form:
#   make tf-apply  ENV=dev
#   make inv       ENV=stage
#   make ping      ENV=prod
#
# PROD SAFETY (guard rails):
#   - prod mutating/destructive targets require CONFIRM=YES
#   - prod targets must be run from git branch "main"
#   - prod targets verify AWS Account ID and AWS region via AWS CLI (sts/config)
#   - prod apply is wired to an explicit saved plan file (prod-plan -> prod-apply)
#
# Examples:
#   make prod-plan         CONFIRM=YES
#   make prod-apply        CONFIRM=YES
#   make prod-destroy      CONFIRM=YES
#
# Notes:
#   - Non-prod environments (dev/stage) remain straightforward and interactive.
#   - Plan files are written to a dedicated local folder (not committed).

SHELL := /bin/bash

# Repo root (so plan file paths work even with terraform -chdir=...)
ROOT_DIR         := $(shell pwd)

ENV              ?= dev
TF_DIR           := terraform/envs/$(ENV)
INV              := ansible/inventory/envs/$(ENV)/hosts.ini

# Plan files are ephemeral artifacts. Keep them out of env directories.
PLAN_DIR         := $(ROOT_DIR)/.terraform-plans
PLANFILE         := $(PLAN_DIR)/$(ENV).tfplan

# Guard settings (edit if you move regions/accounts)
EXPECTED_AWS_ACCOUNT_ID ?= 675138612079
EXPECTED_AWS_REGION     ?= us-east-1

.PHONY: help ip \
        dev-set-ip stage-set-ip prod-set-ip \
        tf-init tf-plan tf-apply tf-output tf-destroy \
        inv ping ansible validate check health \
        dev-init dev-plan dev-apply dev-output dev-inv dev-ping dev-ansible dev-validate dev-check dev-health dev-destroy \
        stage-init stage-plan stage-apply stage-output stage-inv stage-ping stage-ansible stage-validate stage-check stage-health stage-destroy \
        prod-init prod-plan prod-apply prod-output prod-inv prod-ping prod-ansible prod-validate prod-check prod-health prod-destroy \
        prod-guard prod-guard-confirm prod-guard-main prod-guard-account prod-guard-region _prod-apply

help:
	@echo "Targets:"
	@echo "  make ip"
	@echo "  make dev-set-ip|stage-set-ip|prod-set-ip"
	@echo "  make tf-init|tf-plan|tf-apply|tf-output|tf-destroy ENV=dev|stage|prod"
	@echo "  make inv|ping|ansible|validate|check|health      ENV=dev|stage|prod"
	@echo ""
	@echo "PROD safety:"
	@echo "  make prod-plan    CONFIRM=YES"
	@echo "  make prod-apply   CONFIRM=YES"
	@echo "  make prod-destroy CONFIRM=YES"
	@echo ""
	@echo "Guard settings:"
	@echo "  EXPECTED_AWS_ACCOUNT_ID=$(EXPECTED_AWS_ACCOUNT_ID)"
	@echo "  EXPECTED_AWS_REGION=$(EXPECTED_AWS_REGION)"

ip:
	curl -sS checkip.amazonaws.com ; echo

# -------------------------
# IP helpers (tfvars update)
# -------------------------

dev-set-ip:
	@ip="$$(curl -sS checkip.amazonaws.com)"; \
	file="terraform/envs/dev/terraform.tfvars"; \
	echo "Setting my_ip_cidr to $$ip/32 in $$file"; \
	if grep -q '^my_ip_cidr' "$$file"; then \
		sed -i.bak "s|^my_ip_cidr *=.*|my_ip_cidr    = \"$$ip/32\"|g" "$$file"; \
	else \
		echo "my_ip_cidr    = \"$$ip/32\"" >> "$$file"; \
	fi

stage-set-ip:
	@ip="$$(curl -sS checkip.amazonaws.com)"; \
	file="terraform/envs/stage/terraform.tfvars"; \
	echo "Setting my_ip_cidr to $$ip/32 in $$file"; \
	if grep -q '^my_ip_cidr' "$$file"; then \
		sed -i.bak "s|^my_ip_cidr *=.*|my_ip_cidr    = \"$$ip/32\"|g" "$$file"; \
	else \
		echo "my_ip_cidr    = \"$$ip/32\"" >> "$$file"; \
	fi

prod-set-ip:
	@ip="$$(curl -sS checkip.amazonaws.com)"; \
	file="terraform/envs/prod/terraform.tfvars"; \
	echo "Setting my_ip_cidr to $$ip/32 in $$file"; \
	if grep -q '^my_ip_cidr' "$$file"; then \
		sed -i.bak "s|^my_ip_cidr *=.*|my_ip_cidr    = \"$$ip/32\"|g" "$$file"; \
	else \
		echo "my_ip_cidr    = \"$$ip/32\"" >> "$$file"; \
	fi

# -------------------------
# Terraform (generic)
# -------------------------

tf-init:
	terraform -chdir=$(TF_DIR) init

# Create a saved plan file
tf-plan:
	@mkdir -p "$(PLAN_DIR)"
	terraform -chdir=$(TF_DIR) plan -out="$(PLANFILE)"

# Apply (interactive) for non-prod. Prod uses prod-apply below.
tf-apply:
	terraform -chdir=$(TF_DIR) apply

tf-output:
	terraform -chdir=$(TF_DIR) output public_instance_public_ip

tf-destroy:
	terraform -chdir=$(TF_DIR) destroy

# -------------------------
# Ansible (generic)
# -------------------------

inv:
	python3 ansible/inventory/generate_inventory.py $(ENV)

ping:
	ansible -i $(INV) public  -m ping
	ansible -i $(INV) private -m ping

ansible:
	ansible-playbook -i $(INV) ansible/playbooks/site.yml --tags baseline,web,app,validate

validate:
	@echo "Host identity check via nginx → private app:"
	@PUB_IP="$$(terraform -chdir=$(TF_DIR) output -raw public_instance_public_ip)" ; \
	curl -sS "http://$$PUB_IP/app/" | grep hostname

health:
	@echo "Health endpoint headers (nginx → private app):"
	@PUB_IP="$$(terraform -chdir=$(TF_DIR) output -raw public_instance_public_ip)" ; \
	curl -sS -i "http://$$PUB_IP/app/healthz" | head

check:
	ansible-playbook -i $(INV) ansible/playbooks/site.yml --check --diff --tags baseline,web,app,validate

# -------------------------
# DEV convenience targets
# -------------------------

dev-init       : ; $(MAKE) tf-init     ENV=dev
dev-plan       : ; $(MAKE) tf-plan     ENV=dev
dev-apply      : ; $(MAKE) tf-apply    ENV=dev
dev-output     : ; $(MAKE) tf-output   ENV=dev
dev-inv        : ; $(MAKE) inv         ENV=dev
dev-ping       : ; $(MAKE) ping        ENV=dev
dev-ansible    : ; $(MAKE) ansible     ENV=dev
dev-validate   : ; $(MAKE) validate    ENV=dev
dev-health     : ; $(MAKE) health      ENV=dev
dev-check      : ; $(MAKE) check       ENV=dev
dev-destroy    : ; $(MAKE) tf-destroy  ENV=dev

# -------------------------
# STAGE convenience targets
# -------------------------

stage-init     : ; $(MAKE) tf-init     ENV=stage
stage-plan     : ; $(MAKE) tf-plan     ENV=stage
stage-apply    : ; $(MAKE) tf-apply    ENV=stage
stage-output   : ; $(MAKE) tf-output   ENV=stage
stage-inv      : ; $(MAKE) inv         ENV=stage
stage-ping     : ; $(MAKE) ping        ENV=stage
stage-ansible  : ; $(MAKE) ansible     ENV=stage
stage-validate : ; $(MAKE) validate    ENV=stage
stage-health   : ; $(MAKE) health      ENV=stage
stage-check    : ; $(MAKE) check       ENV=stage
stage-destroy  : ; $(MAKE) tf-destroy  ENV=stage

# -------------------------
# PROD safety guard rails
# -------------------------

# Guard 1: explicit confirmation for mutating/destructive prod operations.
prod-guard-confirm:
	@if [ "$(CONFIRM)" != "YES" ]; then \
		echo "ERROR: Production operation blocked."; \
		echo "       Re-run with CONFIRM=YES"; \
		exit 1; \
	fi

# Guard 2: require git branch main (prevents accidental prod work from feature branches).
prod-guard-main:
	@branch="$$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")" ; \
	if [ "$$branch" != "main" ]; then \
		echo "ERROR: prod targets must be run from branch 'main' (current: $$branch)" ; \
		exit 1 ; \
	fi

# Guard 3: require correct AWS Account ID (prevents running prod in the wrong AWS account).
# Uses AWS STS for a structured signal of “who am I authenticated as?”
prod-guard-account:
	@acct="$$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)" ; \
	if [ -z "$$acct" ]; then \
		echo "ERROR: Unable to determine AWS Account ID (is AWS CLI configured/authorized?)" ; \
		exit 1 ; \
	fi ; \
	if [ "$$acct" != "$(EXPECTED_AWS_ACCOUNT_ID)" ]; then \
		echo "ERROR: Wrong AWS account for prod." ; \
		echo "       Expected: $(EXPECTED_AWS_ACCOUNT_ID)" ; \
		echo "       Current : $$acct" ; \
		exit 1 ; \
	fi

# Guard 4: require correct AWS region (prevents accidentally running prod in a different region).
# Prefer AWS_REGION/AWS_DEFAULT_REGION; fall back to aws configure.
prod-guard-region:
	@region="$${AWS_REGION:-$${AWS_DEFAULT_REGION:-$$(aws configure get region 2>/dev/null || true)}}" ; \
	if [ -z "$$region" ]; then \
		echo "ERROR: Unable to determine AWS region (set AWS_REGION or configure AWS CLI)." ; \
		exit 1 ; \
	fi ; \
	if [ "$$region" != "$(EXPECTED_AWS_REGION)" ]; then \
		echo "ERROR: Wrong AWS region for prod." ; \
		echo "       Expected: $(EXPECTED_AWS_REGION)" ; \
		echo "       Current : $$region" ; \
		exit 1 ; \
	fi

# Composite guard for prod targets (non-mutating can use this too).
prod-guard: prod-guard-main prod-guard-account prod-guard-region

# -------------------------
# PROD convenience targets
# -------------------------

# Non-mutating prod targets enforce the “correct account + region + main branch” signal.
prod-init      : prod-guard ; $(MAKE) tf-init    ENV=prod
prod-output    : prod-guard ; $(MAKE) tf-output  ENV=prod
prod-inv       : prod-guard ; $(MAKE) inv        ENV=prod
prod-ping      : prod-guard ; $(MAKE) ping       ENV=prod
prod-ansible   : prod-guard ; $(MAKE) ansible    ENV=prod
prod-validate  : prod-guard ; $(MAKE) validate   ENV=prod
prod-health    : prod-guard ; $(MAKE) health     ENV=prod
prod-check     : prod-guard ; $(MAKE) check      ENV=prod

# Plan is non-mutating, but we still require the structured safety signals.
# (Optional confirmation makes "prod actions are deliberate" muscle memory.)
prod-plan      : prod-guard prod-guard-confirm ; $(MAKE) tf-plan    ENV=prod

# Apply is wired to the saved plan file created by prod-plan, and requires CONFIRM=YES.
prod-apply: prod-guard prod-guard-confirm
	@$(MAKE) _prod-apply ENV=prod

_prod-apply:
	@if [ ! -f "$(PLANFILE)" ]; then \
		echo "ERROR: Missing plan file: $(PLANFILE)" ; \
		echo "       Run: make prod-plan CONFIRM=YES" ; \
		exit 1 ; \
	fi
	terraform -chdir=$(TF_DIR) apply "$(PLANFILE)"
	
# Destroy is destructive, so it requires CONFIRM=YES.
prod-destroy: prod-guard prod-guard-confirm
	$(MAKE) tf-destroy ENV=prod
