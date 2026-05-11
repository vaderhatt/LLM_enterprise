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
     (Generates: hosts.ini.generated)
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
cd /mnt/raid1/LLM_enterprise_git/LLM_enterprise
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
cd /mnt/raid1/LLM_enterprise_git/LLM_enterprise/live/dev
terragrunt plan        # Review the infrastructure changes
terragrunt apply       # Provision VMs, network, storage pool
```

This creates:
- 3 control-plane VMs (cp1, cp2, cp3) at 10.10.1.11-13
- 3 worker VMs (worker1, worker2, worker3) at 10.10.1.21-23
- Libvirt network `dev-rke2-net`
- Libvirt storage pool `rke2-storage`
- Cloud-init configurations with SSH keys for the `ansible` user

**Generated files:**
- `ansible/inventory/hosts.ini.generated` - Dynamic inventory

#### Step 2: Verify VM Connectivity

```bash
cd /mnt/raid1/LLM_enterprise_git/LLM_enterprise/ansible

# Test SSH connectivity to all nodes
ansible all -i inventory/hosts.ini.generated -m ping
```

**Expected output:**
```
cp1 | SUCCESS => {"ansible_facts": {...}, "changed": false, "ping": "pong"}
cp2 | SUCCESS => {"ansible_facts": {...}, "changed": false, "ping": "pong"}
...
```

#### Step 3: Run Ansible Playbooks

```bash
cd /mnt/raid1/LLM_enterprise_git/LLM_enterprise/ansible

# 1. Prepare the OS on all nodes
ansible-playbook playbooks/prerequisites.yml -i inventory/hosts.ini.generated -b

# 2. Deploy RKE2
ansible-playbook playbooks/deploy-rke2.yml -i inventory/hosts.ini.generated -b
```

## Configuration

### SSH Keys

The SSH public key is defined in [terraform/variables.tf](terraform/variables.tf):

```hcl
variable "ssh_public_key" {
  description = "SSH public key for the ansible user (ed25519 format)"
  type        = string
  sensitive   = true
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJuWkPR+Y0sH478sr0MqR3AhSVohoYQLvOsehR0VELxq admin@w237.net"
}

variable "ansible_ssh_private_key_file" {
  description = "Path to the SSH private key for the ansible user"
  type        = string
  default     = "~/.ssh/id_ed25519"
}
```

**To use your own SSH keys:**

1. Generate a new key pair (if needed):
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "ansible@rke2"
   ```

2. Deploy the public key to VMs and set private key path:
   ```bash
   cd live/dev
   export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
   export TF_VAR_ansible_ssh_private_key_file="~/.ssh/id_ed25519"
   terragrunt apply
   ```

   Or create `live/dev/terraform.tfvars`:
   ```hcl
   ssh_public_key                = "ssh-ed25519 YOUR_PUBLIC_KEY_HERE"
   ansible_ssh_private_key_file  = "~/.ssh/id_ed25519"
   ```

The generated Ansible inventory will reference the specified private key path for SSH connections.

### Network Configuration

Edit [terraform/variables.tf](terraform/variables.tf):

```hcl
variable "network_cidr" {
  default = "10.10.1.0/24"
}

variable "control_plane_ips" {
  default = ["10.10.1.11", "10.10.1.12", "10.10.1.13"]
}

variable "worker_ips" {
  default = ["10.10.1.21", "10.10.1.22", "10.10.1.23"]
}
```

### VM Sizing

Edit [terraform/variables.tf](terraform/variables.tf):

```hcl
variable "control_plane_vm" {
  default = {
    cpus         = 2
    memory_mib   = 4096
    disk_size_gb = 20
  }
}

variable "worker_vm" {
  default = {
    cpus         = 2
    memory_mib   = 2048
    disk_size_gb = 10
  }
}
```

## Generated Files

After `terragrunt apply`, the following files are automatically generated:

```
ansible/inventory/hosts.ini.generated
```

This file is generated from [terraform/inventory.tpl](terraform/inventory.tpl) and contains:
- Control plane nodes in `[controlplane]` group
- Worker nodes in `[worker]` group
- SSH connection parameters for each node

**Note:** This file is in `.gitignore` and should not be committed.

## Troubleshooting

### SSH Connection Issues

If `ansible all -i inventory/hosts.ini.generated -m ping` fails:

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

The [libvirt_pool resource](terraform/main.tf) is automatically created. Ensure libvirt is installed:

```bash
sudo apt-get install libvirt-bin
sudo systemctl start libvirtd
```

### Ansible Playbook Issues

Check prerequisites playbook logs:

```bash
ansible-playbook playbooks/prerequisites.yml -i inventory/hosts.ini.generated -b -vvv
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
│   │   ├── hosts.ini            # Manual inventory (reference)
│   │   └── hosts.ini.generated  # Auto-generated by Terraform
│   └── roles/
│       └── rke2-ansible/        # RKE2 Ansible role
├── deploy.sh                    # Automated deployment script
└── live/
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
