#!/bin/bash
# RKE2 Infrastructure Deployment Script
# Orchestrates Terraform provisioning and Ansible deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
LIVE_DEV_DIR="$PROJECT_ROOT/live/dev"
ANSIBLE_KEY_DIR="$ANSIBLE_DIR/.ssh"
ANSIBLE_KEY_SOURCE="/home/ansible/.ssh/id_ed25519"
ANSIBLE_KEY_PATH="$ANSIBLE_KEY_DIR/id_ed25519"
ANSIBLE_PUBLIC_KEY_PATH="$ANSIBLE_KEY_PATH.pub"
ANSIBLE_KNOWN_HOSTS_PATH="$ANSIBLE_KEY_DIR/known_hosts"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    command -v terraform &> /dev/null || { log_warn "terraform not found"; return 1; }
    command -v terragrunt &> /dev/null || { log_warn "terragrunt not found"; return 1; }
    command -v ansible &> /dev/null || { log_warn "ansible not found"; return 1; }
    command -v ansible-playbook &> /dev/null || { log_warn "ansible-playbook not found"; return 1; }
    command -v ssh-keygen &> /dev/null || { log_warn "ssh-keygen not found"; return 1; }
    command -v ssh-keyscan &> /dev/null || { log_warn "ssh-keyscan not found"; return 1; }
    command -v sudo &> /dev/null || { log_warn "sudo not found"; return 1; }
    
    log_success "All prerequisites met"
}

# Copy Ansible SSH key into the Ansible project tree
setup_ansible_ssh_key() {
    log_info "Preparing Ansible SSH key..."

    mkdir -p "$ANSIBLE_KEY_DIR"
    chmod 700 "$ANSIBLE_KEY_DIR"

    if [ ! -f "$ANSIBLE_KEY_SOURCE" ] && ! sudo -n test -f "$ANSIBLE_KEY_SOURCE"; then
        log_warn "Source key not found: $ANSIBLE_KEY_SOURCE"
        return 1
    fi

    if [ -r "$ANSIBLE_KEY_SOURCE" ]; then
        cp "$ANSIBLE_KEY_SOURCE" "$ANSIBLE_KEY_PATH"
    else
        sudo cp "$ANSIBLE_KEY_SOURCE" "$ANSIBLE_KEY_PATH"
        sudo chown "$(id -u):$(id -g)" "$ANSIBLE_KEY_PATH"
    fi
    chmod 600 "$ANSIBLE_KEY_PATH"

    if [ -f "$ANSIBLE_KEY_SOURCE.pub" ] || sudo -n test -f "$ANSIBLE_KEY_SOURCE.pub"; then
        if [ -r "$ANSIBLE_KEY_SOURCE.pub" ]; then
            cp "$ANSIBLE_KEY_SOURCE.pub" "$ANSIBLE_PUBLIC_KEY_PATH"
        else
            sudo cp "$ANSIBLE_KEY_SOURCE.pub" "$ANSIBLE_PUBLIC_KEY_PATH"
            sudo chown "$(id -u):$(id -g)" "$ANSIBLE_PUBLIC_KEY_PATH"
        fi
    else
        ssh-keygen -y -f "$ANSIBLE_KEY_PATH" > "$ANSIBLE_PUBLIC_KEY_PATH"
    fi
    chmod 644 "$ANSIBLE_PUBLIC_KEY_PATH"

    export TF_VAR_ssh_public_key
    TF_VAR_ssh_public_key="$(cat "$ANSIBLE_PUBLIC_KEY_PATH")"
    export TF_VAR_ansible_ssh_private_key_file="$ANSIBLE_KEY_PATH"

    log_success "Ansible SSH key ready at: $ANSIBLE_KEY_PATH"
}

# Terraform plan and apply
terraform_apply() {
    log_info "Running Terraform plan and apply..."
    cd "$LIVE_DEV_DIR"
    
    terragrunt plan
    read -p "Review the plan above. Continue with apply? (yes/no): " -r
    if [[ $REPLY == "yes" ]]; then
        terragrunt apply -auto-approve
        log_success "Terraform apply completed"
    else
        log_warn "Terraform apply skipped"
        exit 1
    fi
}

configure_inventory_ssh_paths() {
    local inventory_path="$1"

    sed -i "s|ansible_ssh_private_key_file=[^[:space:]]*|ansible_ssh_private_key_file=$ANSIBLE_KEY_PATH|g" "$inventory_path"
    sed -i "/^ansible_ssh_common_args=/d" "$inventory_path"
    printf "ansible_ssh_common_args='-o UserKnownHostsFile=%s -o StrictHostKeyChecking=yes'\n" "$ANSIBLE_KNOWN_HOSTS_PATH" >> "$inventory_path"
}

# Generate Ansible inventory
generate_inventory() {
    log_info "Generating Ansible inventory from Terraform outputs..."
    cd "$LIVE_DEV_DIR"
    
    INVENTORY_PATH="$ANSIBLE_DIR/inventory/hosts.ini.generated"
    
    # Terragrunt runs Terraform from cache, so copy the freshest generated file out.
    CACHE_INVENTORY=$(find .terragrunt-cache -name "hosts.ini.generated" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR == 1 {print $2}')
    if [ -n "$CACHE_INVENTORY" ] && [ -f "$CACHE_INVENTORY" ]; then
        log_info "Found generated inventory in cache, copying to expected location..."
        mkdir -p "$(dirname "$INVENTORY_PATH")"
        cp "$CACHE_INVENTORY" "$INVENTORY_PATH"
        configure_inventory_ssh_paths "$INVENTORY_PATH"
        log_success "Inventory copied to: $INVENTORY_PATH"
        return 0
    fi
    
    if [ -f "$INVENTORY_PATH" ]; then
        configure_inventory_ssh_paths "$INVENTORY_PATH"
        log_success "Inventory already available at: $INVENTORY_PATH"
        return 0
    fi
    
    log_warn "Inventory file not found at: $INVENTORY_PATH or in cache"
    return 1
}

prepare_known_hosts() {
    log_info "Preparing Ansible SSH known_hosts..."
    cd "$ANSIBLE_DIR"

    local inventory="inventory/hosts.ini.generated"
    if [ ! -f "$inventory" ]; then
        log_warn "Inventory not found: $inventory"
        return 1
    fi

    : > "$ANSIBLE_KNOWN_HOSTS_PATH"
    awk '{ for (field = 1; field <= NF; field++) if ($field ~ /^ansible_host=/) { sub(/^ansible_host=/, "", $field); print $field } }' "$inventory" | sort -u | while read -r host; do
        ssh-keyscan -T 5 -H "$host" >> "$ANSIBLE_KNOWN_HOSTS_PATH" 2>/dev/null || true
    done
    chmod 644 "$ANSIBLE_KNOWN_HOSTS_PATH"
    log_success "Ansible known_hosts ready at: $ANSIBLE_KNOWN_HOSTS_PATH"
}

# Wait for VMs to be ready
wait_for_vms() {
    log_info "Waiting for VMs to be ready (30 seconds for cloud-init)..."
    sleep 30
    log_success "VMs should be ready"
}

# Test SSH connectivity
test_ssh_connectivity() {
    log_info "Testing SSH connectivity to all nodes..."
    cd "$ANSIBLE_DIR"
    
    INVENTORY="inventory/hosts.ini.generated"
    if [ ! -f "$INVENTORY" ]; then
        log_warn "Inventory not found: $INVENTORY"
        return 1
    fi
    
    ansible all -i "$INVENTORY" -m ping
    log_success "SSH connectivity verified"
}

# Run Ansible prerequisites playbook
run_prerequisites() {
    log_info "Running Ansible prerequisites playbook..."
    cd "$ANSIBLE_DIR"
    
    INVENTORY="inventory/hosts.ini.generated"
    ansible-playbook playbooks/prerequisites.yml -i "$INVENTORY" -b
    log_success "Prerequisites playbook completed"
}

# Run RKE2 deployment
run_rke2_deploy() {
    log_info "Running RKE2 deployment playbook..."
    cd "$ANSIBLE_DIR"
    
    INVENTORY="inventory/hosts.ini.generated"
    ansible-playbook playbooks/deploy-rke2.yml -i "$INVENTORY" -b
    log_success "RKE2 deployment completed"
}

# Main workflow
main() {
    log_info "Starting RKE2 Infrastructure Deployment"
    
    check_prerequisites || exit 1
    setup_ansible_ssh_key || exit 1
    terraform_apply || exit 1
    generate_inventory || exit 1
    prepare_known_hosts || exit 1
    wait_for_vms
    test_ssh_connectivity || { log_warn "SSH connectivity test failed. Check network and SSH keys."; exit 1; }
    read -p "Ready to run Ansible playbooks? (yes/no): " -r || REPLY="no"
    if [[ $REPLY == "yes" ]]; then
        run_prerequisites || exit 1
        run_rke2_deploy || exit 1
        log_success "RKE2 cluster deployment completed!"
    else
        log_warn "Ansible playbooks skipped"
        log_info "To run manually, use:"
        log_info "  ansible-playbook ansible/playbooks/prerequisites.yml -i ansible/inventory/hosts.ini.generated -b"
        log_info "  ansible-playbook ansible/playbooks/deploy-rke2.yml -i ansible/inventory/hosts.ini.generated -b"
    fi
}

main "$@"
