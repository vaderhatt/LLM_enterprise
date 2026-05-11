variable "data_dir" {
  description = "Base directory for VM disks, cloud-init ISOs, and source images"
  type        = string
}

variable "ubuntu_image_path" {
  description = "Path to the Ubuntu Server 26.04 Resolute QCOW2 image. Defaults to <data_dir>/img/ubuntu-26.04-server-cloudimg-amd64.img."
  type        = string
  default     = null
}

variable "storage_pool" {
  description = "Base libvirt storage pool name for VM disks and cloud-init ISOs. The environment name is prefixed by Terraform."
  type        = string
  default     = "rke2-storage"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "dev"
}

variable "control_plane_vm" {
  description = "Sizing for control-plane VMs"
  type = object({
    cpus         = number
    memory_mib   = number
    disk_size_gb = number
  })
  default = {
    cpus         = 2
    memory_mib   = 4096
    disk_size_gb = 20
  }
}

variable "worker_vm" {
  description = "Sizing for worker VMs"
  type = object({
    cpus         = number
    memory_mib   = number
    disk_size_gb = number
  })
  default = {
    cpus         = 2
    memory_mib   = 2048
    disk_size_gb = 10
  }
}

variable "network_name" {
  description = "Libvirt network name for the RKE2 VMs"
  type        = string
  default     = "rke2-net"
}

variable "network_cidr" {
  description = "CIDR for the libvirt network"
  type        = string
  default     = "10.10.1.0/24"
}

variable "network_gateway" {
  description = "Gateway address for the libvirt network"
  type        = string
  default     = "10.10.1.1"
}

variable "control_plane_ips" {
  description = "Static IPs for control plane nodes"
  type        = list(string)
  default     = ["10.10.1.11", "10.10.1.12", "10.10.1.13"]
}

variable "worker_ips" {
  description = "Static IPs for worker nodes"
  type        = list(string)
  default     = ["10.10.1.21", "10.10.1.22", "10.10.1.23"]
}

variable "ssh_public_key" {
  description = "SSH public key for the ansible user (ed25519 format)"
  type        = string
  sensitive   = true
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJuWkPR+Y0sH478sr0MqR3AhSVohoYQLvOsehR0VELxq admin@w237.net"
}

variable "ansible_user" {
  description = "Username for Ansible SSH access"
  type        = string
  default     = "ansible"
}

variable "ansible_ssh_private_key_file" {
  description = "Path to the SSH private key for the ansible user"
  type        = string
  default     = ".ssh/id_ed25519"
}
