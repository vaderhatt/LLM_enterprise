# RKE2 Cluster Deployment

This project provides Ansible playbooks and Terraform configurations to deploy an RKE2 Kubernetes cluster on Ubuntu Server hosts.

## Provisioning Hosts

The hosts are QEMU/KVM headless VMs running on a single Gentoo physical machine. You need to provision 6 Ubuntu Server 22.04 LTS VMs:
- 3 control plane nodes (10.10.1.11-13)
- 3 worker nodes (10.10.1.21-23)

**Prerequisites for Gentoo Host:**
- libvirt and QEMU installed and running
- Ubuntu 22.04 QCOW2 image downloaded to `/mnt/raid1/LLM_enterprise_storage/img/ubuntu-22.04-base.qcow2`

**Steps:**
1. Set up VirtualBox host-only network:
   ```bash
   VBoxManage hostonlyif create
   VBoxManage hostonlyif ipconfig vboxnet0 --ip 10.10.1.1 --netmask 255.255.255.0
   ```

2. Download Ubuntu 22.04 cloud image:
   ```bash
   wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O /mnt/raid1/LLM_enterprise_storage/img/ubuntu-22.04-base.qcow2
   ```

3. Set up libvirt/QEMU on Gentoo host as described in "Provisioning Hosts" section.
4. Run Terraform to create 6 headless VMs:
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

5. VMs will be created with static IPs on 10.10.1.0/24 and start in headless mode.

## Prerequisites

- Ansible installed on the control machine
- SSH access to all Ubuntu Server hosts (user: ansible with sudo privileges)
- Ubuntu Server 22.04 LTS hosts with network connectivity between them

## Usage

1. Provision the 6 Ubuntu Server hosts as described above.
2. IPs are automatically configured on VMs via Terraform and cloud-init (10.10.1.0/24 network).
3. Run prerequisites: `ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/prerequisites.yml`
4. Deploy RKE2: `ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy-rke2.yml`
5. Retrieve kubeconfig from `./kubeconfig` and use `kubectl` to manage the cluster.

## Notes

- Uses systemd as the init system (standard on Ubuntu Server).
- 3 control planes provide high availability (odd number for etcd quorum).
- 3 worker nodes for workload distribution.
- Network: 10.10.1.0/24 with static IPs configured via VirtualBox host-only network.
- All VMs run headless on a single Gentoo physical machine with VirtualBox.
- Test on development environment first.