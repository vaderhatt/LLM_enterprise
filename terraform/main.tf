terraform {
  backend "local" {}

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_pool" "rke2" {
  name = var.storage_pool
  type = "dir"
  path = "/var/lib/libvirt/images/${var.storage_pool}"
}

resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu-base.qcow2"
  pool   = libvirt_pool.rke2.name
  source = var.ubuntu_image_path
  format = "qcow2"

  depends_on = [libvirt_pool.rke2]
}

locals {
  env_prefix = var.environment != "" ? "${var.environment}-" : ""

  control_plane_nodes = {
    for idx, name in ["cp1", "cp2", "cp3"] : name => {
      ip = var.control_plane_ips[idx]
    }
  }

  worker_nodes = {
    for idx, name in ["worker1", "worker2", "worker3"] : name => {
      ip = var.worker_ips[idx]
    }
  }
}

resource "libvirt_network" "rke2_net" {
  name      = "${local.env_prefix}${var.network_name}"
  mode      = "nat"
  addresses = [var.network_cidr]

  dhcp {
    enabled = false
  }

  dns {
    enabled = true
  }
}

module "control_plane" {
  source   = "./modules/node"
  for_each = local.control_plane_nodes

  name                        = "${local.env_prefix}${each.key}"
  ip_address                  = each.value.ip
  ubuntu_image_base_volume_id = libvirt_volume.ubuntu_base.id
  vm                          = var.control_plane_vm
  network_id                  = libvirt_network.rke2_net.id
  storage_pool                = var.storage_pool
  user_data                   = templatefile("${path.module}/cloud_init.cfg", { hostname = each.key, ansible_user = var.ansible_user, ssh_public_key = var.ssh_public_key })
  network_config              = templatefile("${path.module}/network_config.cfg", { ip_address = each.value.ip, network_gateway = var.network_gateway })
}

module "worker" {
  source   = "./modules/node"
  for_each = local.worker_nodes

  name                        = "${local.env_prefix}${each.key}"
  ip_address                  = each.value.ip
  ubuntu_image_base_volume_id = libvirt_volume.ubuntu_base.id
  vm                          = var.worker_vm
  network_id                  = libvirt_network.rke2_net.id
  storage_pool                = var.storage_pool
  user_data                   = templatefile("${path.module}/cloud_init.cfg", { hostname = each.key, ansible_user = var.ansible_user, ssh_public_key = var.ssh_public_key })
  network_config              = templatefile("${path.module}/network_config.cfg", { ip_address = each.value.ip, network_gateway = var.network_gateway })
}
