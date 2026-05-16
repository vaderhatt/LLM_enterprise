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
  load_balancer_ip  = coalesce(var.load_balancer_ip, cidrhost(var.network_cidr, 10))
  domain_controller_ip = coalesce(
    var.domain_controller_ip,
    cidrhost(var.network_cidr, 30)
  )
  load_balancer_hostname = coalesce(
    var.load_balancer_hostname,
    var.environment != "" ? "lb.${var.environment}.${var.internal_domain}" : "lb.${var.internal_domain}"
  )
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

  load_balancer_haproxy_config = templatefile("${path.module}/haproxy.cfg.tpl", {
    control_plane_nodes = local.control_plane_nodes
    ingress_nodes       = { worker1 = local.worker_nodes["worker1"] }
  })

  load_balancer_haproxy_config_indented = "      ${replace(chomp(local.load_balancer_haproxy_config), "\n", "\n      ")}"
}

resource "libvirt_network" "rke2_net" {
  name      = "${local.env_prefix}${var.network_name}"
  mode      = "nat"
  addresses = [var.network_cidr]
  autostart = true

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

module "load_balancer" {
  source = "./modules/node"

  depends_on = [null_resource.storage_pool_active]

  name                        = "${local.env_prefix}lb"
  ip_address                  = local.load_balancer_ip
  ubuntu_image_base_volume_id = libvirt_volume.ubuntu_base.id
  vm                          = var.load_balancer_vm
  network_id                  = libvirt_network.rke2_net.id
  storage_pool                = local.storage_pool_name
  user_data = templatefile("${path.module}/load_balancer_cloud_init.cfg", {
    hostname       = "lb"
    ansible_user   = var.ansible_user
    ssh_public_key = var.ssh_public_key
    haproxy_config = local.load_balancer_haproxy_config_indented
  })
  network_config = templatefile("${path.module}/network_config.cfg", { ip_address = local.load_balancer_ip, network_gateway = var.network_gateway })
}

module "domain_controller" {
  source = "./modules/node"

  depends_on = [null_resource.storage_pool_active]

  name                        = "${local.env_prefix}addc1"
  ip_address                  = local.domain_controller_ip
  ubuntu_image_base_volume_id = libvirt_volume.ubuntu_base.id
  vm                          = var.domain_controller_vm
  network_id                  = libvirt_network.rke2_net.id
  storage_pool                = local.storage_pool_name
  user_data                   = templatefile("${path.module}/cloud_init.cfg", { hostname = "addc1", ansible_user = var.ansible_user, ssh_public_key = var.ssh_public_key })
  network_config              = templatefile("${path.module}/network_config.cfg", { ip_address = local.domain_controller_ip, network_gateway = var.network_gateway })
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
    environment             = var.environment
    control_plane_nodes     = module.control_plane
    worker_nodes            = module.worker
    load_balancer_node      = module.load_balancer
    domain_controller_node  = module.domain_controller
    load_balancer_hostname  = local.load_balancer_hostname
    internal_domain         = var.internal_domain
    samba_ad_realm          = var.samba_ad_realm
    samba_ad_netbios_domain = var.samba_ad_netbios_domain
  })
}
