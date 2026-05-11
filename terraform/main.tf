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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

locals {
  env_prefix        = var.environment != "" ? "${var.environment}-" : ""
  data_dir          = trimsuffix(var.data_dir, "/")
  storage_pool_name = "${local.env_prefix}${var.storage_pool}"
  storage_pool_path = "${local.data_dir}/VM/${local.storage_pool_name}"
  ubuntu_image_path = coalesce(var.ubuntu_image_path, "${local.data_dir}/img/ubuntu-26.04-server-cloudimg-amd64.img")
}

resource "null_resource" "storage_pool_directory" {
  triggers = {
    path = local.storage_pool_path
  }

  provisioner "local-exec" {
    command = "mkdir -p ${self.triggers.path}"
  }
}

resource "libvirt_pool" "rke2" {
  name = local.storage_pool_name
  type = "dir"
  path = local.storage_pool_path

  depends_on = [null_resource.storage_pool_directory]
}

resource "null_resource" "storage_pool_active" {
  triggers = {
    pool = libvirt_pool.rke2.name
    path = libvirt_pool.rke2.path
  }

  provisioner "local-exec" {
    command = "virsh -c qemu:///system pool-info ${self.triggers.pool} | grep -q 'State:.*running' || virsh -c qemu:///system pool-start ${self.triggers.pool}; virsh -c qemu:///system pool-refresh ${self.triggers.pool}"
  }

  depends_on = [libvirt_pool.rke2]
}

resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu-base.qcow2"
  pool   = libvirt_pool.rke2.name
  source = local.ubuntu_image_path
  format = "qcow2"

  depends_on = [null_resource.storage_pool_active]
}

locals {
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

  depends_on = [null_resource.storage_pool_active]

  name                        = "${local.env_prefix}${each.key}"
  ip_address                  = each.value.ip
  ubuntu_image_base_volume_id = libvirt_volume.ubuntu_base.id
  vm                          = var.control_plane_vm
  network_id                  = libvirt_network.rke2_net.id
  storage_pool                = local.storage_pool_name
  user_data                   = templatefile("${path.module}/cloud_init.cfg", { hostname = each.key, ansible_user = var.ansible_user, ssh_public_key = var.ssh_public_key })
  network_config              = templatefile("${path.module}/network_config.cfg", { ip_address = each.value.ip, network_gateway = var.network_gateway })
}

module "worker" {
  source   = "./modules/node"
  for_each = local.worker_nodes

  depends_on = [null_resource.storage_pool_active]

  name                        = "${local.env_prefix}${each.key}"
  ip_address                  = each.value.ip
  ubuntu_image_base_volume_id = libvirt_volume.ubuntu_base.id
  vm                          = var.worker_vm
  network_id                  = libvirt_network.rke2_net.id
  storage_pool                = local.storage_pool_name
  user_data                   = templatefile("${path.module}/cloud_init.cfg", { hostname = each.key, ansible_user = var.ansible_user, ssh_public_key = var.ssh_public_key })
  network_config              = templatefile("${path.module}/network_config.cfg", { ip_address = each.value.ip, network_gateway = var.network_gateway })
}

# Generate Ansible inventory from infrastructure
locals {
  ansible_inventory = templatefile("${path.module}/inventory.tpl", {
    environment                  = var.environment
    ansible_user                 = var.ansible_user
    ansible_ssh_private_key_file = var.ansible_ssh_private_key_file
    control_plane_nodes          = module.control_plane
    worker_nodes                 = module.worker
  })
}
