# RKE2 Infrastructure Deployment Guide

This guide covers the complete Infrastructure as Code (IaC) integration for deploying an RKE2 Kubernetes cluster using Terraform and Ansible.

## Architecture

```
┌─────────────────────────────────────────┐
│  Terraform (Infrastructure Provisioning) │
│  ├─ Libvirt VMs (3 control-plane, 3 workers)
│  ├─ Cloud-init (SSH keys, user creation)
│  └─ Network configuration
└─────────────────────────────────────────┘
                    ↓
    (Generates: dev.ini, stage.ini, or prod.ini)
                    ↓
┌─────────────────────────────────────────┐
│  Ansible (OS Preparation & Deployment)  │
│  ├─ Prerequisites: kernel modules, sysctl
│  └─ RKE2: server & agent installation
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│        RKE2 Kubernetes Cluster          │
└─────────────────────────────────────────┘
```

## Quick Start

### 1. Automated Deployment (Recommended)

```bash
# From the project root
chmod +x deploy.sh
./deploy.sh
```

This script will:
- Check prerequisites (terraform, terragrunt, ansible)
- Run `terragrunt plan` and `terragrunt apply`
- Generate Ansible inventory from Terraform outputs
- Wait for cloud-init to complete
- Test SSH connectivity
- Run Ansible playbooks (prerequisites + RKE2 deployment)

### 2. Manual Step-by-Step Deployment

#### Step 1: Provision Infrastructure with Terraform

```bash
# From the project root
cd live/dev
terragrunt plan        # Review the infrastructure changes
terragrunt apply       # Provision VMs, network, storage pool
```

This creates:
- 3 control-plane VMs (cp1, cp2, cp3) at 10.10.1.11-13
- 3 worker VMs (worker1, worker2, worker3) at 10.10.1.21-23
- Libvirt network `dev-rke2-net`
- Libvirt storage pool `dev-rke2-storage`
- VM disks and cloud-init ISOs under the shared `data_dir` input from [live/root.hcl](live/root.hcl)
- Cloud-init configurations with SSH keys for the `ansible` user

**Generated files:**
- `ansible/inventory/dev.ini` - Dynamic inventory for the dev environment

#### Step 2: Verify VM Connectivity

```bash
# From the project root
cd ansible

# Test SSH connectivity to all nodes
ansible all -i inventory/dev.ini -m ping
```

**Expected output:**
```
cp1 | SUCCESS => {"ansible_facts": {...}, "changed": false, "ping": "pong"}
cp2 | SUCCESS => {"ansible_facts": {...}, "changed": false, "ping": "pong"}
...
```

#### Step 3: Run Ansible Playbooks

```bash
# From the project root
cd ansible

# 1. Prepare the OS on all nodes
ansible-playbook playbooks/prerequisites.yml -i inventory/dev.ini -b

# 2. Deploy RKE2
ansible-playbook playbooks/deploy-rke2.yml -i inventory/dev.ini -b
```

## Configuration

### SSH Keys

The deployment script keeps Ansible SSH material under the Ansible project tree:

```bash
ansible/.ssh/id_ed25519
ansible/.ssh/id_ed25519.pub
ansible/.ssh/known_hosts
```

These files are generated runtime artifacts and are ignored by git. `deploy.sh` copies the private/public key from `${HOME}/.ssh/id_ed25519*` by default, fixes permissions, exports the public key to Terraform for cloud-init, and rewrites the generated inventory to use paths relative to the Ansible project directory. Set `ANSIBLE_KEY_SOURCE` before running the script to use a different local source key.

Direct Terragrunt runs read the cloud-init public key from `ansible/.ssh/id_ed25519.pub` by default. Set `SSH_PUBLIC_KEY_FILE` to use a different public key file:

```bash
SSH_PUBLIC_KEY_FILE=/path/to/id_ed25519.pub terragrunt plan
```

The related Terraform variables are defined in [terraform/variables.tf](terraform/variables.tf):

```hcl
variable "data_dir" {
  description = "Base directory for VM disks, cloud-init ISOs, and source images"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for the ansible user (ed25519 format)"
  type        = string
  sensitive   = true
}
```

Ansible connection defaults live in [ansible/ansible.cfg](ansible/ansible.cfg):

```ini
remote_user = ansible
private_key_file = .ssh/id_ed25519
```

**To use a different source key:**

1. Create or install the key you want to use locally:
   ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "ansible@rke2"
   ```

2. Run deployment from the repo root:
   ```bash
  ./deploy.sh
   ```

The generated Ansible inventory will reference `.ssh/id_ed25519` and `.ssh/known_hosts` relative to `ansible/`, so stale entries in the caller's global `~/.ssh/known_hosts` do not break redeployments.

### Network Configuration

Edit the target environment file, for example [live/dev/terragrunt.hcl](live/dev/terragrunt.hcl):

```hcl
network_cidr     = "10.10.1.0/24"
network_gateway  = "10.10.1.1"
control_plane_ips = ["10.10.1.11", "10.10.1.12", "10.10.1.13"]
worker_ips        = ["10.10.1.21", "10.10.1.22", "10.10.1.23"]
```

### VM Sizing

Shared VM sizing defaults are defined in [live/root.hcl](live/root.hcl):

```hcl
control_plane_vm = {
  cpus         = 2
  memory_mib   = 4096
  disk_size_gb = 50
}

worker_vm = {
  cpus         = 2
  memory_mib   = 16536
  disk_size_gb = 50
}
```

Override these in an environment `terragrunt.hcl` only when that environment needs different sizing.

## Generated Files

After `deploy.sh` runs, the following files are generated from Terragrunt outputs:

```
ansible/inventory/dev.ini
ansible/inventory/stage.ini
ansible/inventory/prod.ini
ansible/inventory/all.ini
```

The environment inventory content is rendered by Terraform from [terraform/inventory.tpl](terraform/inventory.tpl), exposed through `terragrunt output -raw ansible_inventory`, and written to `ansible/inventory/<env>.ini`. `ansible/inventory/all.ini` is generated from all available environment inventories. It contains:
- Environment-specific control plane groups such as `[dev_controlplane]`
- Environment-specific worker groups such as `[dev_worker]`
- Aggregate `[controlplane]` and `[worker]` groups in `all.ini`
- RKE2 role groups in `[rke2_servers]`, `[rke2_agents]`, and `[rke2_cluster]`
- SSH connection parameters for each node

**Note:** These generated inventory files are in `.gitignore` and should not be committed.

## Troubleshooting

### SSH Connection Issues

If `ansible all -i inventory/dev.ini -m ping` fails:

1. **Check VM status:**
   ```bash
   virsh list
   virsh domifaddr cp1
   ```

2. **Wait longer for cloud-init:**
   ```bash
   ssh -i ~/.ssh/id_rsa ansible@10.10.1.11 "cloud-init status --wait"
   ```

3. **Verify SSH key:**
   ```bash
   ssh -i ~/.ssh/id_rsa -v ansible@10.10.1.11
   ```

### Terraform Issues

If `terragrunt apply` fails with storage pool error:

```
Error: can't find storage pool 'rke2-storage'
```

The [libvirt_pool resource](terraform/main.tf) is automatically created with an environment prefix, such as `dev-rke2-storage`. Ensure libvirt is installed:

```bash
sudo apt-get install libvirt-bin
sudo systemctl start libvirtd
```

### Ansible Playbook Issues

Check prerequisites playbook logs:

```bash
ansible-playbook playbooks/prerequisites.yml -i inventory/dev.ini -b -vvv
```

## File Structure

```
LLM_enterprise/
├── terraform/
│   ├── main.tf                  # Main configuration (pool, volume, modules)
│   ├── variables.tf             # Variables (SSH keys, sizing, networking)
│   ├── outputs.tf               # Outputs (inventory generation)
│   ├── cloud_init.cfg           # Cloud-init template
│   ├── inventory.tpl            # Ansible inventory template
│   └── modules/
│       └── node/                # VM module
├── ansible/
│   ├── playbooks/
│   │   ├── prerequisites.yml    # OS preparation
│   │   └── deploy-rke2.yml      # RKE2 deployment
│   ├── inventory/
│   │   ├── dev.ini              # Generated dev inventory
│   │   ├── stage.ini            # Generated stage inventory
│   │   ├── prod.ini             # Generated prod inventory
│   │   └── all.ini              # Generated aggregate inventory
│   └── roles/
│       └── rke2-ansible/        # RKE2 Ansible role
├── deploy.sh                    # Automated deployment script
└── live/
  ├── root.hcl                 # Shared Terragrunt state configuration
    └── dev/                     # Terragrunt environment
        ├── terragrunt.hcl
        └── terraform.tfstate
```

## Next Steps

After RKE2 deployment completes:

1. **Get kubeconfig:**
   ```bash
   scp -i ~/.ssh/id_rsa ansible@10.10.1.11:/etc/rancher/rke2/rke2.yaml ./kubeconfig
   export KUBECONFIG=$(pwd)/kubeconfig
   kubectl get nodes
   ```

2. **Access the cluster:**
   ```bash
   kubectl cluster-info
   kubectl get pods -A
   ```

## References

- [RKE2 Documentation](https://docs.rke2.io/)
- [RKE2 Ansible Repository](https://github.com/rancherfederal/rke2-ansible)
- [Terraform libvirt Provider](https://github.com/dmacvicar/terraform-provider-libvirt)
