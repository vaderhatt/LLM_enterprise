output "control_plane_nodes" {
  description = "Control plane node details"
  value = {
    for name, node in module.control_plane : name => {
      ip   = node.ip_address
      name = node.name
    }
  }
}

output "worker_nodes" {
  description = "Worker node details"
  value = {
    for name, node in module.worker : name => {
      ip   = node.ip_address
      name = node.name
    }
  }
}

output "ansible_inventory" {
  description = "Ansible inventory for RKE2 deployment"
  value       = local.ansible_inventory
}

output "ansible_inventory_path" {
  description = "Path to generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
}

locals {
  ansible_inventory = templatefile("${path.module}/inventory.tpl", {
    ansible_user        = var.ansible_user
    control_plane_nodes = module.control_plane
    worker_nodes        = module.worker
  })
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory/hosts.ini.generated"
  content  = local.ansible_inventory

  file_permission = "0644"

  lifecycle {
    ignore_changes = []
  }
}
