variable "ubuntu_image_path" {
  description = "Path to the Ubuntu Server 22.04 QCOW2 image"
  type        = string
  default     = "/mnt/raid1/LLM_enterprise_storage/img/ubuntu-22.04-base.qcow2"
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
