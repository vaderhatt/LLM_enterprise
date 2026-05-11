variable "data_dir" {
  description = "Base directory for VM disks, cloud-init ISOs, and source images"
  type        = string

  validation {
    condition     = startswith(var.data_dir, "/") && length(trimspace(var.data_dir)) > 1
    error_message = "data_dir must be an absolute path."
  }
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

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+$", var.storage_pool))
    error_message = "storage_pool must contain only letters, numbers, dots, underscores, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be one of: dev, stage, prod."
  }
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

  validation {
    condition     = var.control_plane_vm.cpus > 0 && var.control_plane_vm.memory_mib >= 1024 && var.control_plane_vm.disk_size_gb > 0
    error_message = "control_plane_vm must use positive CPU and disk values, and at least 1024 MiB memory."
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

  validation {
    condition     = var.worker_vm.cpus > 0 && var.worker_vm.memory_mib >= 1024 && var.worker_vm.disk_size_gb > 0
    error_message = "worker_vm must use positive CPU and disk values, and at least 1024 MiB memory."
  }
}

variable "network_name" {
  description = "Libvirt network name for the RKE2 VMs"
  type        = string
  default     = "rke2-net"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+$", var.network_name))
    error_message = "network_name must contain only letters, numbers, dots, underscores, and hyphens."
  }
}

variable "network_cidr" {
  description = "CIDR for the libvirt network"
  type        = string
  default     = "10.10.1.0/24"

  validation {
    condition     = can(cidrhost(var.network_cidr, 0))
    error_message = "network_cidr must be a valid IPv4 or IPv6 CIDR block."
  }
}

variable "network_gateway" {
  description = "Gateway address for the libvirt network"
  type        = string
  default     = "10.10.1.1"

  validation {
    condition     = can(cidrhost("${var.network_gateway}/32", 0))
    error_message = "network_gateway must be a valid IPv4 address."
  }
}

variable "control_plane_ips" {
  description = "Static IPs for control plane nodes"
  type        = list(string)
  default     = ["10.10.1.11", "10.10.1.12", "10.10.1.13"]

  validation {
    condition     = length(var.control_plane_ips) == 3 && alltrue([for ip in var.control_plane_ips : can(cidrhost("${ip}/32", 0))])
    error_message = "control_plane_ips must contain exactly three valid IPv4 addresses."
  }
}

variable "worker_ips" {
  description = "Static IPs for worker nodes"
  type        = list(string)
  default     = ["10.10.1.21", "10.10.1.22", "10.10.1.23"]

  validation {
    condition     = length(var.worker_ips) == 3 && alltrue([for ip in var.worker_ips : can(cidrhost("${ip}/32", 0))])
    error_message = "worker_ips must contain exactly three valid IPv4 addresses."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for the ansible user (ed25519 format)"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^ssh-(ed25519|rsa|ecdsa)", var.ssh_public_key))
    error_message = "ssh_public_key must be an OpenSSH public key."
  }
}

variable "ansible_user" {
  description = "Username for Ansible SSH access"
  type        = string
  default     = "ansible"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]*(\\$)?$", var.ansible_user))
    error_message = "ansible_user must look like a valid Linux user name."
  }
}
