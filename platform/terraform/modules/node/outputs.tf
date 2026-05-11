output "name" {
  description = "Name of the VM"
  value       = var.name
}

output "ip_address" {
  description = "Static IP address assigned to the VM"
  value       = var.ip_address
}

output "domain_id" {
  description = "Libvirt domain ID for the VM"
  value       = libvirt_domain.vm.id
}

output "volume_id" {
  description = "Libvirt volume ID for the VM disk"
  value       = libvirt_volume.vm.id
}

output "cloudinit_id" {
  description = "Libvirt cloudinit disk ID"
  value       = libvirt_cloudinit_disk.init.id
}