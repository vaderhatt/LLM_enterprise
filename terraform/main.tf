terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.6"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Ubuntu Server 22.04 LTS image path and VM settings are defined in variables.tf
resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu-base.qcow2"
  pool   = "default"
  source = var.ubuntu_image_path
  format = "qcow2"
}

resource "libvirt_volume" "cp1" {
  name           = "cp1.qcow2"
  base_volume_id = libvirt_volume.ubuntu_base.id
  pool           = "default"
  size           = var.vm_disk_size_gb * 1024 * 1024 * 1024
}

resource "libvirt_volume" "cp2" {
  name           = "cp2.qcow2"
  base_volume_id = libvirt_volume.ubuntu_base.id
  pool           = "default"
  size           = var.vm_disk_size_gb * 1024 * 1024 * 1024
}

resource "libvirt_volume" "cp3" {
  name           = "cp3.qcow2"
  base_volume_id = libvirt_volume.ubuntu_base.id
  pool           = "default"
  size           = var.vm_disk_size_gb * 1024 * 1024 * 1024
}

resource "libvirt_volume" "worker1" {
  name           = "worker1.qcow2"
  base_volume_id = libvirt_volume.ubuntu_base.id
  pool           = "default"
  size           = var.vm_disk_size_gb * 1024 * 1024 * 1024
}

resource "libvirt_volume" "worker2" {
  name           = "worker2.qcow2"
  base_volume_id = libvirt_volume.ubuntu_base.id
  pool           = "default"
  size           = var.vm_disk_size_gb * 1024 * 1024 * 1024
}

resource "libvirt_volume" "worker3" {
  name           = "worker3.qcow2"
  base_volume_id = libvirt_volume.ubuntu_base.id
  pool           = "default"
  size           = var.vm_disk_size_gb * 1024 * 1024 * 1024
}

resource "libvirt_network" "rke2_net" {
  name      = var.network_name
  mode      = "nat"
  addresses = [var.network_cidr]
  dhcp {
    enabled = false
  }
  dns {
    enabled = true
  }
}

resource "libvirt_cloudinit_disk" "cp1_init" {
  name           = "cp1-init.iso"
  pool           = "default"
  user_data      = templatefile("${path.module}/cloud_init.cfg", { hostname = "cp1" })
  network_config = templatefile("${path.module}/network_config.cfg", { ip_address = var.control_plane_ips[0] })
}

resource "libvirt_cloudinit_disk" "cp2_init" {
  name           = "cp2-init.iso"
  pool           = "default"
  user_data      = templatefile("${path.module}/cloud_init.cfg", { hostname = "cp2" })
  network_config = templatefile("${path.module}/network_config.cfg", { ip_address = var.control_plane_ips[1] })
}

resource "libvirt_cloudinit_disk" "cp3_init" {
  name           = "cp3-init.iso"
  pool           = "default"
  user_data      = templatefile("${path.module}/cloud_init.cfg", { hostname = "cp3" })
  network_config = templatefile("${path.module}/network_config.cfg", { ip_address = var.control_plane_ips[2] })
}

resource "libvirt_cloudinit_disk" "worker1_init" {
  name           = "worker1-init.iso"
  pool           = "default"
  user_data      = templatefile("${path.module}/cloud_init.cfg", { hostname = "worker1" })
  network_config = templatefile("${path.module}/network_config.cfg", { ip_address = var.worker_ips[0] })
}

resource "libvirt_cloudinit_disk" "worker2_init" {
  name           = "worker2-init.iso"
  pool           = "default"
  user_data      = templatefile("${path.module}/cloud_init.cfg", { hostname = "worker2" })
  network_config = templatefile("${path.module}/network_config.cfg", { ip_address = var.worker_ips[1] })
}

resource "libvirt_cloudinit_disk" "worker3_init" {
  name           = "worker3-init.iso"
  pool           = "default"
  user_data      = templatefile("${path.module}/cloud_init.cfg", { hostname = "worker3" })
  network_config = templatefile("${path.module}/network_config.cfg", { ip_address = var.worker_ips[2] })
}

resource "libvirt_domain" "cp1" {
  name   = "cp1"
  memory = var.vm_memory_mib
  vcpu   = var.vm_cpus

  disk {
    volume_id = libvirt_volume.cp1.id
  }

  cloudinit = libvirt_cloudinit_disk.cp1_init.id

  network_interface {
    network_id = libvirt_network.rke2_net.id
  }
}

resource "libvirt_domain" "cp2" {
  name   = "cp2"
  memory = var.vm_memory_mib
  vcpu   = var.vm_cpus

  disk {
    volume_id = libvirt_volume.cp2.id
  }

  cloudinit = libvirt_cloudinit_disk.cp2_init.id

  network_interface {
    network_id = libvirt_network.rke2_net.id
  }
}

resource "libvirt_domain" "cp3" {
  name   = "cp3"
  memory = var.vm_memory_mib
  vcpu   = var.vm_cpus

  disk {
    volume_id = libvirt_volume.cp3.id
  }

  cloudinit = libvirt_cloudinit_disk.cp3_init.id

  network_interface {
    network_id = libvirt_network.rke2_net.id
  }
}

resource "libvirt_domain" "worker1" {
  name   = "worker1"
  memory = var.vm_memory_mib
  vcpu   = var.vm_cpus

  disk {
    volume_id = libvirt_volume.worker1.id
  }

  cloudinit = libvirt_cloudinit_disk.worker1_init.id

  network_interface {
    network_id = libvirt_network.rke2_net.id
  }
}

resource "libvirt_domain" "worker2" {
  name   = "worker2"
  memory = var.vm_memory_mib
  vcpu   = var.vm_cpus

  disk {
    volume_id = libvirt_volume.worker2.id
  }

  cloudinit = libvirt_cloudinit_disk.worker2_init.id

  network_interface {
    network_id = libvirt_network.rke2_net.id
  }
}

resource "libvirt_domain" "worker3" {
  name   = "worker3"
  memory = var.vm_memory_mib
  vcpu   = var.vm_cpus

  disk {
    volume_id = libvirt_volume.worker3.id
  }

  cloudinit = libvirt_cloudinit_disk.worker3_init.id

  network_interface {
    network_id = libvirt_network.rke2_net.id
  }
}
