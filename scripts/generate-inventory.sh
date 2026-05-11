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

(
    cd "$live_env_dir"
    terragrunt output -raw ansible_inventory
) > "$inventory_path"

sed -i "s|ansible_ssh_private_key_file=[^[:space:]]*|ansible_ssh_private_key_file=.ssh/id_ed25519|g" "$inventory_path"
sed -i "/^ansible_ssh_common_args=/d" "$inventory_path"
printf "ansible_ssh_common_args='-o UserKnownHostsFile=.ssh/known_hosts -o StrictHostKeyChecking=yes'\n" >> "$inventory_path"

echo "Generated Ansible inventory: $inventory_path"

{
    printf '# Generated from dev.ini, stage.ini, and prod.ini when present. Do not edit by hand.\n'

    for env in dev stage prod; do
        env_inventory_path="$inventory_dir/$env.ini"
        if [[ -f "$env_inventory_path" ]]; then
            printf '\n# %s\n' "$env_inventory_path"
            awk '
                /^\[all:vars\]$/ { skip = 1; next }
                skip && /^\[/ { skip = 0 }
                !skip { print }
            ' "$env_inventory_path"
        fi
    done

    printf '\n[all:vars]\n'
    printf 'ansible_python_interpreter=/usr/bin/python3\n'
    printf "ansible_ssh_common_args='-o UserKnownHostsFile=.ssh/known_hosts -o StrictHostKeyChecking=yes'\n"
} > "$all_inventory_path"

echo "Generated aggregate Ansible inventory: $all_inventory_path"