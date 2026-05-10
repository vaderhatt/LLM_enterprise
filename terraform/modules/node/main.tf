resource "libvirt_volume" "vm" {
  name           = "${var.name}.qcow2"
  base_volume_id = var.ubuntu_image_base_volume_id
  pool           = "default"
  size           = var.vm.disk_size_gb * 1024 * 1024 * 1024
}

resource "libvirt_cloudinit_disk" "init" {
  name           = "${var.name}-init.iso"
  pool           = "default"
  user_data      = var.user_data
  network_config = var.network_config
}

resource "libvirt_domain" "vm" {
  name   = var.name
  memory = var.vm.memory_mib
  vcpu   = var.vm.cpus

  disk {
    volume_id = libvirt_volume.vm.id
  }

  cloudinit = libvirt_cloudinit_disk.init.id

  network_interface {
    network_id = var.network_id
  }
}