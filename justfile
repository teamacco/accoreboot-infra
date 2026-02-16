# AccoReboot Infrastructure
# Usage: just env=<test|preprod|prod> <recipe>
#
# The env parameter is REQUIRED for all environment-specific recipes.
# Recipes without env dependency: default, infra, sops-edit-common
#
# Secrets are decrypted inline via SOPS (no external wrapper script needed).
# See credentials/*.enc.env.example for the list of required secrets.

# Environment — no default, must be explicitly set
env := ""

# Derived paths
tf_dir := "terraform/environments/" + env
tf_bootstrap_dir := "terraform/bootstrap"
ansible_dir := "ansible"
inventory := ansible_dir / "inventory" / env + ".ini"
server_name := env + "-backend"
creds_dir := "credentials"

# Docker image
backend_src := "../02_poc-accoreboot-communication/backend"
api_image := "accoreboot-api"
api_tag := "latest"

# Guard — fails fast with a clear message if env is not set
_require_env := if env == "" { \
    "echo 'Error: specify environment. Usage: just env=<test|preprod|prod> <recipe>' >&2 && exit 1" \
} else { "true" }

# Inline SOPS decryption — replaces scripts/with-secrets.sh
# Reads each line as KEY=VALUE and exports properly (handles spaces in values).
_load_sops := "while IFS='=' read -r key value; do " + \
    "[[ -z \"$key\" || \"$key\" == \\#* ]] && continue; " + \
    "export \"$key=$value\"; " + \
    "done"
_secrets := if env == "" { "" } else { \
    _load_sops + " < <(sops -d --output-type dotenv " + creds_dir + "/common.enc.env) && " + \
    _load_sops + " < <(sops -d --output-type dotenv " + creds_dir + "/" + env + ".enc.env)" \
}

# List available recipes (default)
[doc("Show available recipes")]
default:
    @just --list --unsorted

# ─── Docker image ─────────────────────────────────────────────────────────────

# Helper: load only common credentials (no env needed)
_common_secrets := _load_sops + " < <(sops -d --output-type dotenv " + creds_dir + "/common.enc.env)"

[doc("Build API Docker image from POC backend")]
build:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _common_secrets }}
    echo "Building ${DOCKERHUB_USERNAME}/{{ api_image }}:{{ api_tag }}..."
    docker build --target production -t "${DOCKERHUB_USERNAME}/{{ api_image }}:{{ api_tag }}" {{ backend_src }}

[doc("Push API Docker image to Docker Hub")]
push:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _common_secrets }}
    echo "Pushing ${DOCKERHUB_USERNAME}/{{ api_image }}:{{ api_tag }}..."
    echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
    docker push "${DOCKERHUB_USERNAME}/{{ api_image }}:{{ api_tag }}"

# ─── Bootstrap (one-time per env) ─────────────────────────────────────────────

[doc("Create S3 state bucket (one-time per env)")]
bootstrap:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _require_env }}
    {{ _secrets }}
    echo "Bootstrapping S3 state bucket for {{ env }}..."
    cd {{ tf_bootstrap_dir }}
    terraform init -upgrade
    terraform apply -auto-approve -var='environment={{ env }}'

# ─── Terraform ────────────────────────────────────────────────────────────────

[doc("Initialize Terraform")]
init:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _require_env }}
    {{ _secrets }}
    echo "Initializing Terraform for {{ env }}..."
    cd {{ tf_dir }} && terraform init

[doc("Plan infrastructure changes")]
plan:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _require_env }}
    {{ _secrets }}
    echo "Planning infrastructure for {{ env }}..."
    cd {{ tf_dir }} && terraform plan

[doc("Apply infrastructure changes")]
apply:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _require_env }}
    {{ _secrets }}
    echo "Applying infrastructure for {{ env }}..."
    cd {{ tf_dir }} && terraform apply -auto-approve

[confirm("This will DESTROY all infrastructure for {{ env }}. Continue?")]
[doc("Destroy infrastructure")]
destroy:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _require_env }}
    {{ _secrets }}
    echo "Destroying infrastructure for {{ env }}..."
    cd {{ tf_dir }} && terraform destroy -auto-approve

[doc("Show Terraform outputs")]
output:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _require_env }}
    {{ _secrets }}
    cd {{ tf_dir }} && terraform output

# ─── Ansible ──────────────────────────────────────────────────────────────────

[doc("Deploy full stack via Ansible")]
deploy:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _require_env }}
    {{ _secrets }}
    echo "Deploying to {{ env }}..."
    cd {{ ansible_dir }} && ansible-playbook playbooks/site.yml -i inventory/{{ env }}.ini -e "target_env={{ env }}"

[doc("Dry-run deploy (check mode)")]
check:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _require_env }}
    {{ _secrets }}
    echo "Dry-run deploy for {{ env }}..."
    cd {{ ansible_dir }} && ansible-playbook playbooks/site.yml -i inventory/{{ env }}.ini -e "target_env={{ env }}" --check --diff

# ─── Instance control (OpenStack) ────────────────────────────────────────────

[doc("Stop backend instance")]
stop:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _require_env }}
    {{ _secrets }}
    echo "Stopping instance {{ server_name }}..."
    openstack server stop {{ server_name }}
    echo "Instance stopped. Use 'just env={{ env }} start' to resume."

[doc("Start a stopped backend instance")]
start:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _require_env }}
    {{ _secrets }}
    echo "Starting instance {{ server_name }}..."
    openstack server start {{ server_name }}
    echo "Instance starting..."
    sleep 5
    openstack server show {{ server_name }} -f value -c status

[doc("Show instance power state")]
state:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _require_env }}
    {{ _secrets }}
    openstack server show {{ server_name }} -f value -c status -c power_state

# ─── Secrets (SOPS) ──────────────────────────────────────────────────────────

[doc("Edit shared credentials (SOPS)")]
sops-edit-common:
    sops credentials/common.enc.env

[doc("Edit environment credentials (SOPS)")]
sops-edit-env:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _require_env }}
    sops credentials/{{ env }}.enc.env

# ─── Utilities ────────────────────────────────────────────────────────────────

[doc("SSH to the backend server")]
ssh:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _require_env }}
    {{ _secrets }}
    IP=$(cd {{ tf_dir }} && terraform output -raw instance_public_ip 2>/dev/null)
    ssh -i ~/.ssh/id_ed25519 ubuntu@"$IP"

[doc("Show container status on the server")]
status:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _require_env }}
    {{ _secrets }}
    IP=$(cd {{ tf_dir }} && terraform output -raw instance_public_ip 2>/dev/null)
    ssh -i ~/.ssh/id_ed25519 ubuntu@"$IP" "docker ps --format 'table {{"{{"}}.Names{{"}}"}}\t{{"{{"}}.Status{{"}}"}}\t{{"{{"}}.Ports{{"}}"}}'"

[doc("Overview of all environments")]
infra:
    #!/usr/bin/env bash
    set -euo pipefail

    envs=(test preprod prod)
    creds_dir="credentials"
    tf_envs="terraform/environments"
    tf_bootstrap="terraform/bootstrap"
    ansible_inv="ansible/inventory"

    # Colors
    G='\033[0;32m' R='\033[0;31m' Y='\033[0;33m' C='\033[0;36m' B='\033[1m' N='\033[0m'
    ok="${G}OK${N}" no="${R}--${N}" warn="${Y}??${N}"

    echo -e "${B}AccoReboot — Infrastructure overview${N}"
    echo ""

    # ── Prerequisites ──
    echo -e "${B}Prerequisites${N}"
    for cmd in terraform ansible-playbook sops openstack; do
      if command -v "$cmd" &>/dev/null; then
        echo -e "  $cmd $(${cmd} --version 2>/dev/null | head -1 | grep -oP '[\d]+\.[\d]+\.[\d]+' | head -1)  ${ok}"
      else
        echo -e "  $cmd  ${R}NOT INSTALLED${N}"
      fi
    done
    if [ -f ~/.config/sops/age/keys.txt ]; then
      echo -e "  age key  ${ok}"
    else
      echo -e "  age key  ${R}MISSING${N} (~/.config/sops/age/keys.txt)"
    fi
    echo ""

    # ── Credentials ──
    echo -e "${B}Credentials (SOPS)${N}"
    if [ -f "$creds_dir/common.enc.env" ]; then
      echo -e "  common.enc.env  ${ok}"
    else
      echo -e "  common.enc.env  ${no}  (copy from .example)"
    fi
    for e in "${envs[@]}"; do
      if [ -f "$creds_dir/$e.enc.env" ]; then
        echo -e "  $e.enc.env      ${ok}"
      else
        echo -e "  $e.enc.env      ${no}"
      fi
    done
    echo ""

    # ── Bootstrap ──
    echo -e "${B}Bootstrap (S3 state bucket)${N}"
    if [ -f "$tf_bootstrap/terraform.tfstate" ]; then
      echo -e "  terraform.tfstate  ${ok}"
    else
      echo -e "  terraform.tfstate  ${no}  (run: just env=test bootstrap)"
    fi
    echo ""

    # ── Environments ──
    echo -e "${B}Environments${N}"
    printf "  ${B}%-10s %-12s %-10s %-18s %-8s${N}\n" "ENV" "CREDENTIALS" "TF STATE" "INSTANCE" "DEPLOY"
    for e in "${envs[@]}"; do
      # Credentials
      if [ -f "$creds_dir/$e.enc.env" ]; then cred="${ok}"; else cred="${no}"; fi

      # Terraform initialized?
      if [ -d "$tf_envs/$e/.terraform" ]; then
        tf_init="${ok}"
      else
        tf_init="${no}"
      fi

      # Inventory = proxy for "terraform apply has been run"
      if [ -f "$ansible_inv/$e.ini" ]; then
        deploy="${ok}"
        ip=$(grep 'ansible_host=' "$ansible_inv/$e.ini" | head -1 | sed 's/.*ansible_host=//')
      else
        deploy="${no}"
        ip=""
      fi

      # Instance status — only if credentials + inventory exist
      instance="${no}"
      if [ -f "$creds_dir/common.enc.env" ] && [ -f "$creds_dir/$e.enc.env" ] && [ -n "$ip" ]; then
        set -a
        eval "$(sops -d --output-type dotenv "$creds_dir/common.enc.env" 2>/dev/null)" 2>/dev/null || true
        eval "$(sops -d --output-type dotenv "$creds_dir/$e.enc.env" 2>/dev/null)" 2>/dev/null || true
        set +a
        power=$(openstack server show "$e-backend" -f value -c power_state 2>/dev/null || true)
        case "$power" in
          1) instance="${G}running${N} ${C}$ip${N}" ;;
          4) instance="${Y}stopped${N}" ;;
          "") instance="${warn}" ;;
          *)  instance="${Y}$power${N}" ;;
        esac
      fi

      printf "  %-10s %-20b %-18b %-26b %-16b\n" "$e" "$cred" "$tf_init" "$instance" "$deploy"
    done
    echo ""

    # ── Health check on running instances ──
    for e in "${envs[@]}"; do
      if [ -f "$ansible_inv/$e.ini" ]; then
        ip=$(grep 'ansible_host=' "$ansible_inv/$e.ini" | head -1 | sed 's/.*ansible_host=//')
        if [ -n "$ip" ]; then
          health=$(curl -sf --connect-timeout 3 "http://$ip/health" 2>/dev/null && echo "ok" || echo "")
          if [ -n "$health" ]; then
            echo -e "  ${G}$e${N}: http://$ip/health → ${ok}"
          fi
        fi
      fi
    done

[doc("Clean generated files")]
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _require_env }}
    echo "Cleaning generated files..."
    rm -f {{ ansible_dir }}/inventory/*.ini
    rm -rf {{ tf_dir }}/.terraform
    rm -f {{ tf_dir }}/.terraform.lock.hcl

# ─── Full workflow ────────────────────────────────────────────────────────────

[doc("Full deploy (build + push + init + apply + deploy)")]
up: build push init apply deploy
    #!/usr/bin/env bash
    set -euo pipefail
    {{ _require_env }}
    {{ _secrets }}
    echo ""
    echo "============================================"
    echo "Infrastructure {{ env }} is up!"
    echo "============================================"
    cd {{ tf_dir }} && terraform output

[confirm("This will DESTROY all infrastructure for {{ env }} and clean files. Continue?")]
[doc("Destroy everything and clean")]
down: destroy clean
    #!/usr/bin/env bash
    {{ _require_env }}
    echo "Infrastructure {{ env }} destroyed."
