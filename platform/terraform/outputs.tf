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

output "ansible_inventory_path" {
  description = "Path to generated Ansible inventory file"
  value       = "ansible/inventory/${var.environment}.ini"
}

output "ansible_inventory" {
  description = "Generated Ansible inventory content"
  value       = local.ansible_inventory
}
