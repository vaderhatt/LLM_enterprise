#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <environment> <terragrunt-env-dir>" >&2
    exit 1
fi

deploy_env="$1"
live_env_dir="$2"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
inventory_dir="$project_root/ansible/inventory"
inventory_path="$inventory_dir/$deploy_env.ini"
all_inventory_path="$inventory_dir/all.ini"

mkdir -p "$(dirname "$inventory_path")"

normalize_host_vars() {
    local path="$1"

    sed -i \
        -e 's/[[:space:]]ansible_user=[^[:space:]]*//g' \
        -e 's/[[:space:]]ansible_ssh_private_key_file=[^[:space:]]*//g' \
        "$path"
}

(
    cd "$live_env_dir"
    terragrunt output -raw ansible_inventory
) > "$inventory_path"

normalize_host_vars "$inventory_path"
sed -i "/^ansible_ssh_common_args=/d" "$inventory_path"
printf "ansible_ssh_common_args='-o UserKnownHostsFile=.ssh/known_hosts -o StrictHostKeyChecking=yes'\n" >> "$inventory_path"

echo "Generated Ansible inventory: $inventory_path"

{
    printf '# Generated from dev.ini, stage.ini, and prod.ini when present. Do not edit by hand.\n'

    for env in dev stage prod; do
        env_inventory_path="$inventory_dir/$env.ini"
        if [[ -f "$env_inventory_path" ]]; then
            normalize_host_vars "$env_inventory_path"

            printf '\n[%s_controlplane]\n' "$env"
            awk -v section="[${env}_controlplane]" '
                $0 == section { in_section = 1; next }
                in_section && /^\[/ { in_section = 0 }
                in_section && NF { print }
            ' "$env_inventory_path"

            printf '\n[%s_worker]\n' "$env"
            awk -v section="[${env}_worker]" '
                $0 == section { in_section = 1; next }
                in_section && /^\[/ { in_section = 0 }
                in_section && NF { print }
            ' "$env_inventory_path"

            printf '\n[%s_load_balancer]\n' "$env"
            awk -v section="[${env}_load_balancer]" '
                $0 == section { in_section = 1; next }
                in_section && /^\[/ { in_section = 0 }
                in_section && NF { print }
            ' "$env_inventory_path"
        fi
    done

    printf '\n[all:children]\n'
    for env in dev stage prod; do
        [[ -f "$inventory_dir/$env.ini" ]] && printf '%s\n' "$env"
    done

    for env in dev stage prod; do
        if [[ -f "$inventory_dir/$env.ini" ]]; then
            printf '\n[%s:children]\n' "$env"
            printf '%s_controlplane\n' "$env"
            printf '%s_worker\n' "$env"
            printf '%s_load_balancer\n' "$env"
        fi
    done

    printf '\n[controlplane:children]\n'
    for env in dev stage prod; do
        [[ -f "$inventory_dir/$env.ini" ]] && printf '%s_controlplane\n' "$env"
    done

    printf '\n[worker:children]\n'
    for env in dev stage prod; do
        [[ -f "$inventory_dir/$env.ini" ]] && printf '%s_worker\n' "$env"
    done

    printf '\n[load_balancer:children]\n'
    for env in dev stage prod; do
        [[ -f "$inventory_dir/$env.ini" ]] && printf '%s_load_balancer\n' "$env"
    done

    printf '\n[all:vars]\n'
    printf 'ansible_python_interpreter=/usr/bin/python3\n'
    printf "ansible_ssh_common_args='-o UserKnownHostsFile=.ssh/known_hosts -o StrictHostKeyChecking=yes'\n"
} > "$all_inventory_path"

echo "Generated aggregate Ansible inventory: $all_inventory_path"