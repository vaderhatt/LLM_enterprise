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
cd terragrunt/dev
terragrunt plan        # Review the infrastructure changes
terragrunt apply       # Provision VMs, network, storage pool
```

This creates:
- 3 control-plane VMs (cp1, cp2, cp3) at 10.10.1.11-13
- 3 worker VMs (worker1, worker2, worker3) at 10.10.1.21-23
- Libvirt network `dev-rke2-net`
- Libvirt storage pool `dev-rke2-storage`
- VM disks and cloud-init ISOs under the shared `data_dir` input from [terragrunt/root.hcl](terragrunt/root.hcl)
- Cloud-init configurations with SSH keys for the `ansible` user

**Generated files:**
- `ansible/inventory/dev.ini` - Dynamic inventory for the dev environment

#### Step 2: Verify VM Connectivity

```bash
# From the platform directory
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
# From the platform directory
cd ansible

# 1. Prepare the OS on all nodes
ansible-playbook playbooks/prerequisites.yml -i inventory/dev.ini -b

# 2. Deploy RKE2
ansible-playbook playbooks/deploy-rke2.yml -i inventory/dev.ini -b

# 3. Bootstrap Flux GitOps
ansible-playbook playbooks/bootstrap-flux.yml -i inventory/dev.ini
```

## Configuration

### SSH Keys

The deployment script keeps Ansible SSH material under the Ansible project tree:

```bash
ansible/.ssh/id_ed25519
ansible/.ssh/id_ed25519.pub
ansible/.ssh/known_hosts
```

These files are generated runtime artifacts and are ignored by git. `deploy.sh` copies the private/public key from `${HOME}/.ssh/id_ed25519*` by default, fixes permissions, and exports the public key to Terraform for cloud-init. Set `ANSIBLE_KEY_SOURCE` before running the script to use a different local source key.

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

Ansible uses `remote_user`, `private_key_file`, and the generated `.ssh/known_hosts` path from [ansible/ansible.cfg](ansible/ansible.cfg), so stale entries in the caller's global `~/.ssh/known_hosts` do not break redeployments.

### Network Configuration

Edit the target environment file, for example [terragrunt/dev/terragrunt.hcl](terragrunt/dev/terragrunt.hcl):

```hcl
network_cidr     = "10.10.1.0/24"
network_gateway  = "10.10.1.1"
control_plane_ips = ["10.10.1.11", "10.10.1.12", "10.10.1.13"]
worker_ips        = ["10.10.1.21", "10.10.1.22", "10.10.1.23"]
```

### VM Sizing

Shared VM sizing defaults are defined in [terragrunt/root.hcl](terragrunt/root.hcl):

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
- SSH connection parameters for each node

`all.ini` intentionally does not define aggregate `rke2_servers`, `rke2_agents`, or `rke2_cluster` groups. Use per-environment inventories such as `dev.ini` for RKE2 deployment, and use `all.ini` for operational tasks across all environments.

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

### Ingress Ownership

The RKE2 bundled ingress controller is disabled in [ansible/playbooks/deploy-rke2.yml](ansible/playbooks/deploy-rke2.yml). Ingress is managed by Flux from [../gitops/infrastructure/ingress-or-gateway](../gitops/infrastructure/ingress-or-gateway), including host ports 80 and 443.

### Cluster Load Balancer

Terraform creates one HAProxy load-balancer VM per environment, such as `dev-lb` at `10.10.1.10` with DNS name `lb.dev.w237.local`. The load balancer forwards RKE2 API traffic on `6443` and registration traffic on `9345` to all control-plane nodes. It also forwards ingress traffic on `80` and `443` to the current ingress node, `worker1`.

After applying Terraform, regenerate inventory through the Terragrunt after-hook or with:

```bash
cd platform/terragrunt/dev
terragrunt apply
```

Point cluster API clients at `https://lb.dev.w237.local:6443` or `https://10.10.1.10:6443`. Point application DNS records such as `k8s.dev.w237.local` at the same load-balancer IP.

### Internal DNS

CoreDNS runs on the load-balancer VM and listens on TCP/UDP port `53`, for example `10.10.1.10` in dev. It serves environment records under `w237.local` and forwards everything else to public upstream resolvers.

Configure or refresh it with:

```bash
cd platform/ansible
ansible-playbook playbooks/configure-dns.yml -i inventory/dev.ini -b
```

Useful dev records include:

```text
lb.dev.w237.local      10.10.1.10
k8s.dev.w237.local     10.10.1.10
cp1.dev.w237.local     10.10.1.11
cp2.dev.w237.local     10.10.1.12
cp3.dev.w237.local     10.10.1.13
worker1.dev.w237.local 10.10.1.21
worker2.dev.w237.local 10.10.1.22
worker3.dev.w237.local 10.10.1.23
```

Test it from the host or a cluster VM:

```bash
dig @10.10.1.10 k8s.dev.w237.local
```

### Ansible Playbook Issues

Check prerequisites playbook logs:

```bash
ansible-playbook playbooks/prerequisites.yml -i inventory/dev.ini -b -vvv
```

### Flux GitOps Bootstrap

Bootstrap Flux after RKE2 is running:

```bash
cd platform/ansible
ansible-playbook playbooks/bootstrap-flux.yml -i inventory/dev.ini
```

By default, Flux watches this repository on branch `main` and applies the matching environment path, such as [../../gitops/clusters/dev](../../gitops/clusters/dev) for the dev inventory. That environment entrypoint points infrastructure reconciliation at `gitops/clusters/<env>/infrastructure`, where environment-specific patches such as Dashboard DNS names are applied. Override the source for forks, private mirrors, or a different environment path:

```bash
ansible-playbook playbooks/bootstrap-flux.yml -i inventory/dev.ini \
   -e flux_git_url=https://github.com/example/LLM_enterprise.git \
   -e flux_git_branch=main \
   -e flux_git_path=./gitops/clusters/dev
```

If the repository is private, provide a GitHub token from the control machine. The playbook stores it in a Kubernetes Secret referenced by the Flux `GitRepository`:

```bash
export GITHUB_USER=<github-user>
export GITHUB_TOKEN=<github-token-with-repo-read-access>
ansible-playbook playbooks/bootstrap-flux.yml -i inventory/dev.ini
```

For a public repository that does not require authentication, disable the token requirement:

```bash
ansible-playbook playbooks/bootstrap-flux.yml -i inventory/dev.ini -e flux_git_auth_required=false
```

You can also pass credentials explicitly:

```bash
ansible-playbook playbooks/bootstrap-flux.yml -i inventory/dev.ini \
   -e flux_git_username=<github-user> \
   -e flux_git_password=<github-token-with-repo-read-access>
```

Check reconciliation:

```bash
kubectl -n flux-system get gitrepositories,kustomizations
```

### Kubernetes Dashboard

Kubernetes Dashboard is managed by Flux from [../gitops/infrastructure/kubernetes-dashboard](../gitops/infrastructure/kubernetes-dashboard). It uses the Flux-managed `nginx` ingress class from [../gitops/infrastructure/ingress-or-gateway](../gitops/infrastructure/ingress-or-gateway) and cert-manager from [../gitops/infrastructure/cert-manager](../gitops/infrastructure/cert-manager).

When Flux is not bootstrapped yet, apply the dependencies and dashboard manually from the repository root:

```bash
kubectl apply -k gitops/infrastructure/cert-manager
kubectl apply -k gitops/infrastructure/ingress-or-gateway
kubectl apply -k gitops/infrastructure/kubernetes-dashboard
```

Point the environment dashboard hostname at an ingress node IP with DNS or `/etc/hosts`, then open:

```text
https://k8s.dev.w237.local/
```

The ingress controller is pinned to `worker1` and binds host ports 80 and 443, so no NodePort suffix is required.

Get the login token:

```bash
kubectl -n kubernetes-dashboard get secret admin-user -o jsonpath='{.data.token}' | base64 -d
```

## File Structure

```
LLM_enterprise/
├── platform/
│   ├── terraform/               # Terraform module/source
│   ├── terragrunt/              # Terragrunt live environments
│   ├── ansible/                 # Playbooks, roles, generated inventories
│   ├── scripts/                 # Helper scripts
│   ├── deploy.sh                # Automated deployment script
│   └── DEPLOYMENT.md            # Platform deployment guide
└── gitops/
   ├── clusters/
   ├── infrastructure/
   └── apps/
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
