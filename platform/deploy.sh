#!/bin/bash
# RKE2 Infrastructure Deployment Script
# Orchestrates Terraform provisioning and Ansible deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
DEPLOY_ENV="${1:-${DEPLOY_ENV:-dev}}"
LIVE_ENV_DIR="$PROJECT_ROOT/terragrunt/$DEPLOY_ENV"
ANSIBLE_SYSTEM_USER="${ANSIBLE_SYSTEM_USER:-ansible}"
ANSIBLE_KEY_DIR="$ANSIBLE_DIR/.ssh"
ANSIBLE_KEY_SOURCE="${ANSIBLE_KEY_SOURCE:-}"
ANSIBLE_KEY_PATH="$ANSIBLE_KEY_DIR/id_ed25519"
ANSIBLE_PUBLIC_KEY_PATH="$ANSIBLE_KEY_PATH.pub"
ANSIBLE_KNOWN_HOSTS_PATH="$ANSIBLE_KEY_DIR/known_hosts"
ANSIBLE_INVENTORY_KNOWN_HOSTS_PATH=".ssh/known_hosts"
ANSIBLE_INVENTORY="inventory/$DEPLOY_ENV.ini"
SAMBA_ADMIN_PASSWORD_FILE="${SAMBA_ADMIN_PASSWORD_FILE:-$ANSIBLE_DIR/.secrets/samba-admin-password}"

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

inventory_hosts() {
    local inventory_path="$1"

    awk '{ for (field = 1; field <= NF; field++) if ($field ~ /^ansible_host=/) { sub(/^ansible_host=/, "", $field); print $field } }' "$inventory_path" | sort -u
}

run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

package_for_command() {
    local package_manager="$1"
    local command_name="$2"

    case "$package_manager:$command_name" in
        apt-get:ansible-playbook) printf 'ansible' ;;
        apt-get:ssh-keygen|apt-get:ssh-keyscan) printf 'openssh-client' ;;
        dnf:ansible-playbook|yum:ansible-playbook) printf 'ansible-core' ;;
        dnf:ssh-keygen|dnf:ssh-keyscan|yum:ssh-keygen|yum:ssh-keyscan) printf 'openssh-clients' ;;
        zypper:ansible-playbook) printf 'ansible' ;;
        zypper:ssh-keygen|zypper:ssh-keyscan) printf 'openssh' ;;
        pacman:ansible-playbook) printf 'ansible' ;;
        pacman:ssh-keygen|pacman:ssh-keyscan) printf 'openssh' ;;
        *) printf '%s' "$command_name" ;;
    esac
}

detect_package_manager() {
    for package_manager in apt-get dnf yum zypper pacman; do
        if command -v "$package_manager" > /dev/null 2>&1; then
            printf '%s' "$package_manager"
            return 0
        fi
    done

    return 1
}

install_missing_prerequisites() {
    local missing_commands=("$@")
    local package_manager
    local packages=()
    local package

    if [ "${#missing_commands[@]}" -eq 0 ]; then
        return 0
    fi

    if ! package_manager="$(detect_package_manager)"; then
        log_warn "Missing commands: ${missing_commands[*]}"
        log_warn "No supported package manager found. Install these commands manually and rerun."
        return 1
    fi

    if [ "$(id -u)" -ne 0 ] && ! command -v sudo > /dev/null 2>&1; then
        log_warn "Missing commands: ${missing_commands[*]}"
        log_warn "sudo is unavailable, so automatic package installation cannot run as root."
        return 1
    fi

    for command_name in "${missing_commands[@]}"; do
        package="$(package_for_command "$package_manager" "$command_name")"
        if [[ ! " ${packages[*]} " =~ " ${package} " ]]; then
            packages+=("$package")
        fi
    done

    log_warn "Missing commands: ${missing_commands[*]}"
    log_info "Detected package manager: $package_manager"
    log_info "Suggested packages: ${packages[*]}"
    read -p "Install missing prerequisite packages automatically? (yes/no): " -r || REPLY="no"
    if [[ $REPLY != "yes" ]]; then
        log_warn "Prerequisite installation skipped"
        return 1
    fi

    case "$package_manager" in
        apt-get)
            run_as_root apt-get update
            run_as_root apt-get install -y "${packages[@]}"
            ;;
        dnf|yum)
            run_as_root "$package_manager" install -y "${packages[@]}"
            ;;
        zypper)
            run_as_root zypper --non-interactive install "${packages[@]}"
            ;;
        pacman)
            run_as_root pacman -Sy --needed --noconfirm "${packages[@]}"
            ;;
    esac
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    local required_commands=(terraform terragrunt ansible ansible-playbook ssh-keygen ssh-keyscan)
    local missing_commands=()
    local command_name

    if [ "$(id -u)" -ne 0 ]; then
        required_commands+=(sudo)
    fi

    for command_name in "${required_commands[@]}"; do
        if ! command -v "$command_name" > /dev/null 2>&1; then
            missing_commands+=("$command_name")
        fi
    done

    if [ "${#missing_commands[@]}" -gt 0 ]; then
        install_missing_prerequisites "${missing_commands[@]}" || return 1

        missing_commands=()
        for command_name in "${required_commands[@]}"; do
            if ! command -v "$command_name" > /dev/null 2>&1; then
                missing_commands+=("$command_name")
            fi
        done

        if [ "${#missing_commands[@]}" -gt 0 ]; then
            log_warn "Still missing required commands after installation attempt: ${missing_commands[*]}"
            return 1
        fi
    fi
    
    log_success "All prerequisites met"
}

check_sensitive_inputs() {
    log_info "Checking required local secret inputs..."

    if [ -z "${SAMBA_ADMIN_PASSWORD:-}" ] && [ ! -s "$SAMBA_ADMIN_PASSWORD_FILE" ]; then
        log_warn "Samba AD Administrator password is required before rollout"
        log_warn "Set SAMBA_ADMIN_PASSWORD or write it to: $SAMBA_ADMIN_PASSWORD_FILE"
        return 1
    fi

    log_success "Required local secret inputs are present"
}

ensure_ansible_system_user() {
    local ansible_home

    if ! id "$ANSIBLE_SYSTEM_USER" > /dev/null 2>&1; then
        log_warn "Local automation user '$ANSIBLE_SYSTEM_USER' does not exist"
        read -p "Create local user '$ANSIBLE_SYSTEM_USER' and generate an SSH keypair for deployments? (yes/no): " -r || REPLY="no"
        if [[ $REPLY != "yes" ]]; then
            log_warn "Local automation user creation skipped"
            return 1
        fi

        run_as_root useradd --create-home --shell /bin/bash "$ANSIBLE_SYSTEM_USER"
    fi

    ansible_home="$(getent passwd "$ANSIBLE_SYSTEM_USER" | cut -d: -f6)"
    if [ -z "$ansible_home" ]; then
        log_warn "Could not determine home directory for user '$ANSIBLE_SYSTEM_USER'"
        return 1
    fi

    run_as_root install -d -m 700 -o "$ANSIBLE_SYSTEM_USER" -g "$ANSIBLE_SYSTEM_USER" "$ansible_home/.ssh"

    if ! run_as_root test -f "$ansible_home/.ssh/id_ed25519"; then
        log_info "Generating SSH keypair for local user '$ANSIBLE_SYSTEM_USER'"
        run_as_root ssh-keygen -t ed25519 -f "$ansible_home/.ssh/id_ed25519" -N "" -C "$ANSIBLE_SYSTEM_USER@$(hostname)"
        run_as_root chown "$ANSIBLE_SYSTEM_USER:$ANSIBLE_SYSTEM_USER" "$ansible_home/.ssh/id_ed25519" "$ansible_home/.ssh/id_ed25519.pub"
    fi

    if [ -z "$ANSIBLE_KEY_SOURCE" ]; then
        ANSIBLE_KEY_SOURCE="$ansible_home/.ssh/id_ed25519"
    fi

    log_success "Local automation user ready: $ANSIBLE_SYSTEM_USER"
    log_info "Using Ansible SSH key source: $ANSIBLE_KEY_SOURCE"
}

# Copy Ansible SSH key into the Ansible project tree
setup_ansible_ssh_key() {
    log_info "Preparing Ansible SSH key..."

    mkdir -p "$ANSIBLE_KEY_DIR"
    chmod 700 "$ANSIBLE_KEY_DIR"

    if [ -z "$ANSIBLE_KEY_SOURCE" ]; then
        log_warn "ANSIBLE_KEY_SOURCE is not set"
        return 1
    fi

    if [ ! -r "$ANSIBLE_KEY_SOURCE" ] && ! run_as_root test -r "$ANSIBLE_KEY_SOURCE"; then
        log_warn "Source key not found: $ANSIBLE_KEY_SOURCE"
        return 1
    fi

    if [ -r "$ANSIBLE_KEY_SOURCE" ]; then
        cp "$ANSIBLE_KEY_SOURCE" "$ANSIBLE_KEY_PATH"
    else
        run_as_root cp "$ANSIBLE_KEY_SOURCE" "$ANSIBLE_KEY_PATH"
        run_as_root chown "$(id -u):$(id -g)" "$ANSIBLE_KEY_PATH"
    fi
    chmod 600 "$ANSIBLE_KEY_PATH"

    if [ -r "$ANSIBLE_KEY_SOURCE.pub" ] || run_as_root test -r "$ANSIBLE_KEY_SOURCE.pub"; then
        if [ -r "$ANSIBLE_KEY_SOURCE.pub" ]; then
            cp "$ANSIBLE_KEY_SOURCE.pub" "$ANSIBLE_PUBLIC_KEY_PATH"
        else
            run_as_root cp "$ANSIBLE_KEY_SOURCE.pub" "$ANSIBLE_PUBLIC_KEY_PATH"
            run_as_root chown "$(id -u):$(id -g)" "$ANSIBLE_PUBLIC_KEY_PATH"
        fi
    else
        ssh-keygen -y -f "$ANSIBLE_KEY_PATH" > "$ANSIBLE_PUBLIC_KEY_PATH"
    fi
    chmod 644 "$ANSIBLE_PUBLIC_KEY_PATH"

    export TF_VAR_ssh_public_key
    TF_VAR_ssh_public_key="$(cat "$ANSIBLE_PUBLIC_KEY_PATH")"

    log_success "Ansible SSH key ready at: $ANSIBLE_KEY_PATH"
}

# Terraform plan and apply
terraform_apply() {
    log_info "Running Terraform plan and apply for $DEPLOY_ENV..."
    cd "$LIVE_ENV_DIR"
    
    terragrunt init
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

    sed -i "/^ansible_ssh_common_args=/d" "$inventory_path"
    printf "ansible_ssh_common_args='-o UserKnownHostsFile=%s -o StrictHostKeyChecking=yes'\n" "$ANSIBLE_INVENTORY_KNOWN_HOSTS_PATH" >> "$inventory_path"
}

# Generate Ansible inventory
generate_inventory() {
    log_info "Generating Ansible inventory from Terraform outputs..."
    cd "$LIVE_ENV_DIR"
    
    INVENTORY_PATH="$ANSIBLE_DIR/$ANSIBLE_INVENTORY"
    mkdir -p "$(dirname "$INVENTORY_PATH")"
    terragrunt output -raw ansible_inventory > "$INVENTORY_PATH"
    configure_inventory_ssh_paths "$INVENTORY_PATH"
    log_success "Inventory written to: $INVENTORY_PATH"
}

prepare_known_hosts() {
    log_info "Preparing Ansible SSH known_hosts..."
    cd "$ANSIBLE_DIR"

    local inventory="$ANSIBLE_INVENTORY"
    if [ ! -f "$inventory" ]; then
        log_warn "Inventory not found: $inventory"
        return 1
    fi

    : > "$ANSIBLE_KNOWN_HOSTS_PATH"
    while read -r host; do
        log_info "Scanning SSH host key for $host..."
        host_key_found=false
        for attempt in {1..36}; do
            if ssh-keyscan -T 5 -H "$host" >> "$ANSIBLE_KNOWN_HOSTS_PATH" 2>/dev/null; then
                host_key_found=true
                break
            fi

            if (( attempt % 6 == 0 )); then
                log_info "Still waiting for SSH host key from $host..."
            fi
        done

        if [ "$host_key_found" != "true" ]; then
            log_warn "Could not collect SSH host key from $host"
            return 1
        fi
    done < <(inventory_hosts "$inventory")
    sort -u -o "$ANSIBLE_KNOWN_HOSTS_PATH" "$ANSIBLE_KNOWN_HOSTS_PATH"
    chmod 644 "$ANSIBLE_KNOWN_HOSTS_PATH"
    log_success "Ansible known_hosts ready at: $ANSIBLE_KNOWN_HOSTS_PATH"
}

# Wait for VMs to be ready
wait_for_vms() {
    log_info "Waiting for VMs to accept SSH..."
    cd "$ANSIBLE_DIR"

    INVENTORY="$ANSIBLE_INVENTORY"
    ansible all -i "$INVENTORY" -m wait_for_connection -a "timeout=180"
    log_success "VMs are reachable over SSH"
}

# Test SSH connectivity
test_ssh_connectivity() {
    log_info "Testing SSH connectivity to all nodes..."
    cd "$ANSIBLE_DIR"
    
    INVENTORY="$ANSIBLE_INVENTORY"
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
    
    INVENTORY="$ANSIBLE_INVENTORY"
    ansible-playbook playbooks/prerequisites.yml -i "$INVENTORY" -b
    log_success "Prerequisites playbook completed"
}

configure_dns_service() {
    log_info "Configuring CoreDNS service on the load balancer..."
    cd "$ANSIBLE_DIR"

    INVENTORY="$ANSIBLE_INVENTORY"
    ansible-playbook playbooks/configure-dns.yml -i "$INVENTORY" -b
    log_success "CoreDNS service configured"
}

load_samba_admin_password() {
    if [ -n "${SAMBA_ADMIN_PASSWORD:-}" ]; then
        export SAMBA_ADMIN_PASSWORD
        return 0
    fi

    if [ -r "$SAMBA_ADMIN_PASSWORD_FILE" ]; then
        SAMBA_ADMIN_PASSWORD="$(tr -d '\r\n' < "$SAMBA_ADMIN_PASSWORD_FILE")"
        export SAMBA_ADMIN_PASSWORD
        return 0
    fi

    return 1
}

configure_samba_addc() {
    log_info "Configuring Samba Active Directory domain controller..."
    cd "$ANSIBLE_DIR"

    if ! load_samba_admin_password; then
        log_warn "SAMBA_ADMIN_PASSWORD is required to configure Samba AD DC"
        log_warn "Set it in the environment or write it to: $SAMBA_ADMIN_PASSWORD_FILE"
        return 1
    fi

    INVENTORY="$ANSIBLE_INVENTORY"
    ansible-playbook playbooks/configure-samba-addc.yml -i "$INVENTORY" -b
    log_success "Samba AD DC configured"
}

configure_vault() {
    log_info "Configuring Vault server..."
    cd "$ANSIBLE_DIR"

    INVENTORY="$ANSIBLE_INVENTORY"
    ansible-playbook playbooks/configure-vault.yml -i "$INVENTORY" -b
    log_success "Vault server configured"
}

configure_ad_ui_secret() {
    log_info "Configuring AD UI Kubernetes secret..."
    cd "$ANSIBLE_DIR"

    INVENTORY="$ANSIBLE_INVENTORY"
    ansible-playbook playbooks/configure-ad-ui-secret.yml -i "$INVENTORY"
    log_success "AD UI secret configured"
}

# Run RKE2 deployment
run_rke2_deploy() {
    log_info "Running RKE2 deployment playbook..."
    cd "$ANSIBLE_DIR"
    
    INVENTORY="$ANSIBLE_INVENTORY"
    ansible-playbook playbooks/deploy-rke2.yml -i "$INVENTORY" -b
    log_success "RKE2 deployment completed"
}

# Bootstrap Flux GitOps
bootstrap_flux() {
    log_info "Bootstrapping Flux GitOps..."
    cd "$ANSIBLE_DIR"

    INVENTORY="$ANSIBLE_INVENTORY"
    ansible-playbook playbooks/bootstrap-flux.yml -i "$INVENTORY"
    log_success "Flux bootstrap completed"
}

# Main workflow
main() {
    log_info "Starting RKE2 Infrastructure Deployment"
    
    check_prerequisites || exit 1
    check_sensitive_inputs || exit 1
    ensure_ansible_system_user || exit 1
    setup_ansible_ssh_key || exit 1
    terraform_apply || exit 1
    generate_inventory || exit 1
    prepare_known_hosts || exit 1
    wait_for_vms
    test_ssh_connectivity || { log_warn "SSH connectivity test failed. Check network and SSH keys."; exit 1; }
    read -p "Ready to run Ansible playbooks? (yes/no): " -r || REPLY="no"
    if [[ $REPLY == "yes" ]]; then
        configure_samba_addc || exit 1
        configure_vault || exit 1
        configure_dns_service || exit 1
        run_prerequisites || exit 1
        run_rke2_deploy || exit 1
        configure_ad_ui_secret || exit 1
        read -p "Ready to bootstrap Flux GitOps? (yes/no): " -r || REPLY="no"
        if [[ $REPLY == "yes" ]]; then
            bootstrap_flux || exit 1
        else
            log_warn "Flux bootstrap skipped"
            log_info "To run manually, use:"
            log_info "  ansible-playbook ansible/playbooks/bootstrap-flux.yml -i ansible/$ANSIBLE_INVENTORY"
        fi
        log_success "RKE2 cluster deployment workflow completed!"
    else
        log_warn "Ansible playbooks skipped"
        log_info "To run manually, use:"
        log_info "  install -d -m 700 ansible/.secrets"
        log_info "  printf '%s\n' '<strong-password>' > ansible/.secrets/samba-admin-password"
        log_info "  chmod 600 ansible/.secrets/samba-admin-password"
        log_info "  ansible-playbook ansible/playbooks/configure-samba-addc.yml -i ansible/$ANSIBLE_INVENTORY -b"
        log_info "  ansible-playbook ansible/playbooks/configure-vault.yml -i ansible/$ANSIBLE_INVENTORY -b"
        log_info "  ansible-playbook ansible/playbooks/configure-dns.yml -i ansible/$ANSIBLE_INVENTORY -b"
        log_info "  ansible-playbook ansible/playbooks/prerequisites.yml -i ansible/$ANSIBLE_INVENTORY -b"
        log_info "  ansible-playbook ansible/playbooks/deploy-rke2.yml -i ansible/$ANSIBLE_INVENTORY -b"
        log_info "  ansible-playbook ansible/playbooks/configure-ad-ui-secret.yml -i ansible/$ANSIBLE_INVENTORY"
        log_info "  ansible-playbook ansible/playbooks/bootstrap-flux.yml -i ansible/$ANSIBLE_INVENTORY"
    fi
}

main "$@"
