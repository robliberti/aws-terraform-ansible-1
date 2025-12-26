# Makefile - AWS Terraform + Ansible Infrastructure Lab
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
#   make tf-apply ENV=dev
#   make inv ENV=stage
#   make ping ENV=prod
#
# PROD SAFETY:
#   make prod-apply   CONFIRM=YES
#   make prod-destroy CONFIRM=YES

SHELL := /bin/bash

ENV     ?= dev
TF_DIR  := terraform/envs/$(ENV)
INV     := ansible/inventory/envs/$(ENV)/hosts.ini

.PHONY: help ip \
        tf-init tf-apply tf-output tf-destroy \
        inv ping ansible validate check health \
        dev-init dev-apply dev-output dev-inv dev-ping dev-ansible dev-validate dev-check dev-health dev-destroy \
        stage-init stage-apply stage-output stage-inv stage-ping stage-ansible stage-validate stage-check stage-health stage-destroy \
        prod-init prod-apply prod-output prod-inv prod-ping prod-ansible prod-validate prod-check prod-health prod-destroy

help:
	@echo "Targets:"
	@echo "  make ip"
	@echo "  make tf-init|tf-apply|tf-output|tf-destroy ENV=dev|stage|prod"
	@echo "  make inv|ping|ansible|validate|check|health ENV=dev|stage|prod"
	@echo ""
	@echo "PROD requires explicit confirmation:"
	@echo "  make prod-apply   CONFIRM=YES"
	@echo "  make prod-destroy CONFIRM=YES"

ip:
	curl -sS checkip.amazonaws.com ; echo

# -------------------------
# Terraform (generic)
# -------------------------

tf-init:
	terraform -chdir=$(TF_DIR) init

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

dev-init       : ; $(MAKE) tf-init    ENV=dev
dev-apply      : ; $(MAKE) tf-apply   ENV=dev
dev-output     : ; $(MAKE) tf-output  ENV=dev
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

stage-init     : ; $(MAKE) tf-init    ENV=stage
stage-apply    : ; $(MAKE) tf-apply   ENV=stage
stage-output   : ; $(MAKE) tf-output  ENV=stage
stage-inv      : ; $(MAKE) inv         ENV=stage
stage-ping     : ; $(MAKE) ping        ENV=stage
stage-ansible  : ; $(MAKE) ansible     ENV=stage
stage-validate : ; $(MAKE) validate    ENV=stage
stage-health   : ; $(MAKE) health      ENV=stage
stage-check    : ; $(MAKE) check       ENV=stage
stage-destroy  : ; $(MAKE) tf-destroy  ENV=stage

# -------------------------
# PROD safety guard
# -------------------------

prod-guard:
	@if [ "$(CONFIRM)" != "YES" ]; then \
		echo "ERROR: Production operation blocked."; \
		echo "       Re-run with CONFIRM=YES"; \
		exit 1; \
	fi

# -------------------------
# PROD convenience targets
# -------------------------

prod-init      : ; $(MAKE) tf-init     ENV=prod
prod-output    : ; $(MAKE) tf-output   ENV=prod
prod-inv       : ; $(MAKE) inv          ENV=prod
prod-ping      : ; $(MAKE) ping         ENV=prod
prod-ansible   : ; $(MAKE) ansible      ENV=prod
prod-validate  : ; $(MAKE) validate     ENV=prod
prod-health    : ; $(MAKE) health       ENV=prod
prod-check     : ; $(MAKE) check        ENV=prod

prod-apply     : prod-guard ; $(MAKE) tf-apply   ENV=prod
prod-destroy   : prod-guard ; $(MAKE) tf-destroy ENV=prod
