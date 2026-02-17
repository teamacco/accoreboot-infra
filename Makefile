# AccoReboot Infrastructure
# Usage: make <target> ENV=<environment>
#
# Secrets are managed with SOPS (.env format). See credentials/*.enc.env.example

ENV ?=
TF_DIR := terraform/environments/$(ENV)
TF_BOOTSTRAP_DIR := terraform/bootstrap
ANSIBLE_DIR := ansible
INVENTORY := $(ANSIBLE_DIR)/inventory/$(ENV).ini
SECRETS := ./scripts/with-secrets.sh $(ENV)
SECRETS_COMMON := ./scripts/with-secrets.sh --common-only
SERVER_NAME := $(ENV)-backend

# Docker image
BACKEND_SRC := ../02_poc-accoreboot-communication/backend
API_IMAGE := accoreboot-api
API_TAG := latest

.PHONY: help build push bootstrap init plan apply destroy output deploy check \
        stop start sops-edit-common sops-edit-env ssh status clean state up down

help:
	@echo "AccoReboot Infrastructure"
	@echo ""
	@echo "Usage: make <target> ENV=<environment>"
	@echo ""
	@echo "Docker:"
	@echo "  build             - Build API Docker image from POC backend"
	@echo "  push              - Push API Docker image to Docker Hub"
	@echo ""
	@echo "Bootstrap (one-time per env):"
	@echo "  bootstrap         - Create S3 bucket for Terraform state"
	@echo ""
	@echo "Terraform:"
	@echo "  init              - Initialize Terraform"
	@echo "  plan              - Plan infrastructure changes"
	@echo "  apply             - Apply infrastructure changes"
	@echo "  destroy           - Destroy infrastructure (with confirmation)"
	@echo "  output            - Show Terraform outputs"
	@echo ""
	@echo "Ansible:"
	@echo "  deploy            - Deploy full stack"
	@echo "  check             - Dry-run deploy (show what would change)"
	@echo ""
	@echo "Instance control:"
	@echo "  stop              - Stop backend instance"
	@echo "  start             - Start a stopped backend instance"
	@echo ""
	@echo "Secrets (SOPS):"
	@echo "  sops-edit-common  - Edit shared credentials"
	@echo "  sops-edit-env     - Edit environment credentials"
	@echo ""
	@echo "Utilities:"
	@echo "  ssh               - SSH to the backend server"
	@echo "  status            - Show container status"
	@echo "  clean             - Clean generated files"
	@echo "  state             - Overview of all environments"
	@echo ""
	@echo "Workflow:"
	@echo "  up                - Full deploy (build + push + init + apply + deploy)"
	@echo "  down              - Destroy everything (with confirmation)"
	@echo ""
	@echo "Examples:"
	@echo "  make up ENV=test"
	@echo "  make deploy ENV=test"
	@echo "  make plan ENV=prod"
	@echo "  make build"
	@echo "  make sops-edit-env ENV=test"
	@echo "  make state"

# ─── Guard ───────────────────────────────────────────────────────────────────

_require_env:
	@if [ -z "$(ENV)" ]; then \
		echo "Error: specify environment. Usage: make <target> ENV=<test|preprod|prod>"; \
		exit 1; \
	fi

# ─── Docker image ────────────────────────────────────────────────────────────

build:
	@echo "Building API Docker image..."
	@$(SECRETS_COMMON) 'echo "Building $${DOCKERHUB_USERNAME}/$(API_IMAGE):$(API_TAG)..." && \
		docker build --target production -t "$${DOCKERHUB_USERNAME}/$(API_IMAGE):$(API_TAG)" $(BACKEND_SRC)'

push:
	@echo "Pushing API Docker image..."
	@$(SECRETS_COMMON) 'echo "$${DOCKERHUB_TOKEN}" | docker login -u "$${DOCKERHUB_USERNAME}" --password-stdin && \
		echo "Pushing $${DOCKERHUB_USERNAME}/$(API_IMAGE):$(API_TAG)..." && \
		docker push "$${DOCKERHUB_USERNAME}/$(API_IMAGE):$(API_TAG)"'

# ─── Bootstrap (one-time per env) ────────────────────────────────────────────

bootstrap: _require_env
	@echo "Bootstrapping S3 state bucket for $(ENV)..."
	@$(SECRETS) "cd $(TF_BOOTSTRAP_DIR) && \
		terraform init -upgrade && \
		terraform apply -auto-approve -var='environment=$(ENV)'"

# ─── Terraform ───────────────────────────────────────────────────────────────

init: _require_env
	@echo "Initializing Terraform for $(ENV)..."
	@$(SECRETS) "cd $(TF_DIR) && terraform init"

plan: _require_env
	@echo "Planning infrastructure for $(ENV)..."
	@$(SECRETS) "cd $(TF_DIR) && terraform plan"

apply: _require_env
	@echo "Applying infrastructure for $(ENV)..."
	@$(SECRETS) "cd $(TF_DIR) && terraform apply -auto-approve"

destroy: _require_env
	@echo ""; \
	read -p "This will DESTROY all infrastructure for $(ENV). Continue? [y/N] " confirm; \
	if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
		echo "Aborted."; \
		exit 1; \
	fi
	@$(SECRETS) "cd $(TF_DIR) && terraform destroy -auto-approve"

output: _require_env
	@$(SECRETS) "cd $(TF_DIR) && terraform output"

# ─── Ansible ─────────────────────────────────────────────────────────────────

deploy: _require_env
	@echo "Deploying to $(ENV)..."
	@$(SECRETS) "cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml -i inventory/$(ENV).ini -e target_env=$(ENV)"

check: _require_env
	@echo "Dry-run deploy for $(ENV)..."
	@$(SECRETS) "cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml -i inventory/$(ENV).ini -e target_env=$(ENV) --check --diff"

# ─── Instance control (OpenStack) ────────────────────────────────────────────

stop: _require_env
	@echo "Stopping instance $(SERVER_NAME)..."
	@$(SECRETS) "openstack server stop $(SERVER_NAME)"
	@echo "Instance stopped. Use 'make start ENV=$(ENV)' to resume."

start: _require_env
	@echo "Starting instance $(SERVER_NAME)..."
	@$(SECRETS) "openstack server start $(SERVER_NAME)"
	@echo "Instance starting..."
	@sleep 5
	@$(SECRETS) "openstack server show $(SERVER_NAME) -f value -c status"

# ─── Secrets (SOPS) ─────────────────────────────────────────────────────────

sops-edit-common:
	@sops credentials/common.enc.env

sops-edit-env: _require_env
	@sops credentials/$(ENV).enc.env

# ─── Utilities ───────────────────────────────────────────────────────────────

ssh: _require_env
	@$(SECRETS) 'IP=$$(cd $(TF_DIR) && terraform output -raw instance_public_ip 2>/dev/null) && ssh -i ~/.ssh/id_ed25519 ubuntu@$$IP'

status: _require_env
	@$(SECRETS) 'IP=$$(cd $(TF_DIR) && terraform output -raw instance_public_ip 2>/dev/null) && ssh -i ~/.ssh/id_ed25519 ubuntu@$$IP "docker ps --format \"table {{.Names}}\t{{.Status}}\t{{.Ports}}\""'

clean: _require_env
	@echo "Cleaning generated files..."
	rm -f $(ANSIBLE_DIR)/inventory/*.ini
	rm -rf $(TF_DIR)/.terraform
	rm -f $(TF_DIR)/.terraform.lock.hcl

state:
	@./scripts/state-overview.sh

# ─── Full workflow ───────────────────────────────────────────────────────────

up: build push init apply deploy
	@echo ""
	@echo "============================================"
	@echo "Infrastructure $(ENV) is up!"
	@echo "============================================"
	@$(SECRETS) "cd $(TF_DIR) && terraform output"

down: _require_env
	@echo ""; \
	read -p "This will DESTROY all infrastructure for $(ENV) and clean files. Continue? [y/N] " confirm; \
	if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
		echo "Aborted."; \
		exit 1; \
	fi
	@$(SECRETS) "cd $(TF_DIR) && terraform destroy -auto-approve"
	@echo "Cleaning generated files..."
	@rm -f $(ANSIBLE_DIR)/inventory/*.ini
	@rm -rf $(TF_DIR)/.terraform
	@rm -f $(TF_DIR)/.terraform.lock.hcl
	@echo "Infrastructure $(ENV) destroyed."
