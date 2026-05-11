variable "name" {
  description = "Hostname for the VM"
  type        = string
}

variable "ip_address" {
  description = "Static IPv4 address for the VM"
  type        = string
}

variable "ubuntu_image_base_volume_id" {
  description = "ID of the base Ubuntu QCOW2 volume"
  type        = string
}

variable "vm" {
  description = "Sizing object for the VM"
  type = object({
    cpus         = number
    memory_mib   = number
    disk_size_gb = number
  })
}

variable "user_data" {
  description = "Rendered cloud-init user-data content"
  type        = string
}

variable "network_config" {
  description = "Rendered cloud-init network configuration"
  type        = string
}

variable "network_id" {
  description = "Libvirt network ID for the VM network interface"
  type        = string
}

variable "storage_pool" {
  description = "Libvirt storage pool name for VM disks and cloud-init ISOs"
  type        = string
}