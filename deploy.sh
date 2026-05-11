#!/bin/bash
# RKE2 Infrastructure Deployment Script
# Orchestrates Terraform provisioning and Ansible deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
LIVE_DEV_DIR="$PROJECT_ROOT/live/dev"

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
    
    log_success "All prerequisites met"
}

# Terraform plan and apply
terraform_apply() {
    log_info "Running Terraform plan and apply..."
    cd "$LIVE_DEV_DIR"
    
    terragrunt plan
    read -p "Review the plan above. Continue with apply? (yes/no): " -r
    if [[ $REPLY == "yes" ]]; then
        terragrunt apply
        log_success "Terraform apply completed"
    else
        log_warn "Terraform apply skipped"
        exit 1
    fi
}

# Generate Ansible inventory
generate_inventory() {
    log_info "Generating Ansible inventory from Terraform outputs..."
    cd "$LIVE_DEV_DIR"
    
    INVENTORY_PATH="$ANSIBLE_DIR/inventory/hosts.ini.generated"
    if [ -f "$INVENTORY_PATH" ]; then
        log_success "Inventory generated at: $INVENTORY_PATH"
    else
        log_warn "Inventory file not found at: $INVENTORY_PATH"
        return 1
    fi
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
    terraform_apply || exit 1
    generate_inventory || exit 1
    wait_for_vms
    test_ssh_connectivity || { log_warn "SSH connectivity test failed. Check network and SSH keys."; exit 1; }
    read -p "Ready to run Ansible playbooks? (yes/no): " -r
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
