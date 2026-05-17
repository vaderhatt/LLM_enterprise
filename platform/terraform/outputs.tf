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

output "load_balancer_node" {
  description = "Cluster load balancer node details"
  value = {
    ip       = module.load_balancer.ip_address
    name     = module.load_balancer.name
    hostname = local.load_balancer_hostname
  }
}

output "vault_node" {
  description = "HashiCorp Vault node details"
  value = {
    ip       = module.vault.ip_address
    name     = module.vault.name
    hostname = "vault.${var.environment}.${var.internal_domain}"
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
