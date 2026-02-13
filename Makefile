# AccoReboot Infrastructure
# Usage: make <target> ENV=<environment>
#
# Secrets are managed with SOPS (.env format). See credentials/*.enc.env.example

ENV ?= test
TF_DIR := terraform/environments/$(ENV)
TF_BOOTSTRAP_DIR := terraform/bootstrap
ANSIBLE_DIR := ansible
INVENTORY := $(ANSIBLE_DIR)/inventory/$(ENV).ini
SECRETS := ./scripts/with-secrets.sh $(ENV)
SERVER_NAME := $(ENV)-backend

.PHONY: help bootstrap init plan apply destroy deploy check ssh status stop start state up down clean output sops-edit-common sops-edit-env

help:
	@echo "AccoReboot Infrastructure"
	@echo ""
	@echo "Usage: make <target> ENV=<environment>"
	@echo ""
	@echo "Bootstrap (one-time per env):"
	@echo "  bootstrap       - Create S3 bucket for Terraform state in the env's OVH project"
	@echo ""
	@echo "Terraform:"
	@echo "  init            - Initialize Terraform (connects to S3 backend)"
	@echo "  plan            - Plan infrastructure changes"
	@echo "  apply           - Apply infrastructure changes (auto-approve)"
	@echo "  destroy         - Destroy infrastructure (auto-approve)"
	@echo "  output          - Show Terraform outputs"
	@echo ""
	@echo "Ansible:"
	@echo "  deploy          - Deploy full stack"
	@echo "  check           - Dry-run deploy (show what would change)"
	@echo ""
	@echo "Instance control:"
	@echo "  stop            - Stop backend instance (without destroying)"
	@echo "  start           - Start a stopped backend instance"
	@echo "  state           - Show instance power state"
	@echo ""
	@echo "Secrets (SOPS):"
	@echo "  sops-edit-common - Edit shared credentials"
	@echo "  sops-edit-env    - Edit environment credentials"
	@echo ""
	@echo "Utilities:"
	@echo "  ssh             - SSH to the backend server"
	@echo "  status          - Show container status"
	@echo "  clean           - Clean generated files"
	@echo ""
	@echo "Workflow:"
	@echo "  up              - Full deploy (init + apply + deploy)"
	@echo "  down            - Destroy everything"
	@echo ""
	@echo "Examples:"
	@echo "  make up ENV=test"
	@echo "  make stop ENV=test"
	@echo "  make start ENV=test"
	@echo "  make plan ENV=prod"
	@echo "  make sops-edit-env ENV=test"

# Bootstrap (one-time per env: creates S3 bucket in the env's OVH project)
bootstrap:
	@echo "Bootstrapping S3 state bucket for $(ENV)..."
	@$(SECRETS) "cd $(TF_BOOTSTRAP_DIR) && \
		terraform init && \
		terraform apply -auto-approve -var='environment=$(ENV)'"

# Terraform
init:
	@echo "Initializing Terraform for $(ENV)..."
	@$(SECRETS) "cd $(TF_DIR) && terraform init"

plan:
	@echo "Planning infrastructure for $(ENV)..."
	@$(SECRETS) "cd $(TF_DIR) && terraform plan"

apply:
	@echo "Applying infrastructure for $(ENV)..."
	@$(SECRETS) "cd $(TF_DIR) && terraform apply -auto-approve"

destroy:
	@echo "Destroying infrastructure for $(ENV)..."
	@$(SECRETS) "cd $(TF_DIR) && terraform destroy -auto-approve"

output:
	@$(SECRETS) "cd $(TF_DIR) && terraform output"

# Ansible
deploy:
	@echo "Deploying to $(ENV)..."
	@$(SECRETS) "cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml -i inventory/$(ENV).ini"

check:
	@echo "Dry-run deploy for $(ENV)..."
	@$(SECRETS) "cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml -i inventory/$(ENV).ini --check --diff"

# Instance control (OpenStack)
stop:
	@echo "Stopping instance $(SERVER_NAME)..."
	@$(SECRETS) "openstack server stop $(SERVER_NAME)"
	@echo "Instance stopped. Use 'make start ENV=$(ENV)' to resume."

start:
	@echo "Starting instance $(SERVER_NAME)..."
	@$(SECRETS) "openstack server start $(SERVER_NAME)"
	@echo "Instance starting..."
	@sleep 5
	@$(SECRETS) "openstack server show $(SERVER_NAME) -f value -c status"

state:
	@$(SECRETS) "openstack server show $(SERVER_NAME) -f value -c status -c power_state"

# Secrets management
sops-edit-common:
	@sops credentials/common.enc.env

sops-edit-env:
	@sops credentials/$(ENV).enc.env

# Utilities
ssh:
	@$(SECRETS) 'IP=$$(cd $(TF_DIR) && terraform output -raw instance_public_ip 2>/dev/null) && ssh -i ~/.ssh/id_ed25519 ubuntu@$$IP'

status:
	@$(SECRETS) 'IP=$$(cd $(TF_DIR) && terraform output -raw instance_public_ip 2>/dev/null) && ssh -i ~/.ssh/id_ed25519 ubuntu@$$IP "docker ps --format \"table {{.Names}}\t{{.Status}}\t{{.Ports}}\""'

clean:
	@echo "Cleaning generated files..."
	rm -f $(ANSIBLE_DIR)/inventory/*.ini
	rm -rf $(TF_DIR)/.terraform
	rm -f $(TF_DIR)/.terraform.lock.hcl

# Full workflow
up: init apply deploy
	@echo ""
	@echo "============================================"
	@echo "Infrastructure $(ENV) is up!"
	@echo "============================================"
	@$(SECRETS) "cd $(TF_DIR) && terraform output"

down: destroy clean
	@echo "Infrastructure $(ENV) destroyed."
