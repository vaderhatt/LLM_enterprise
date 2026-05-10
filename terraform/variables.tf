variable "ubuntu_image_path" {
  description = "Path to the Ubuntu Server 22.04 QCOW2 image"
  type        = string
  default     = "/mnt/raid1/LLM_enterprise_storage/img/ubuntu-22.04-base.qcow2"
}

variable "vm_cpus" {
  description = "Number of virtual CPUs for each VM"
  type        = number
  default     = 2
}

variable "vm_memory_mib" {
  description = "Memory size in MiB for each VM"
  type        = number
  default     = 2048
}

variable "vm_disk_size_gb" {
  description = "Disk size in GiB for each VM"
  type        = number
  default     = 10
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
