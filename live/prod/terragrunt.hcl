include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../..//terraform"

  after_hook "generate_ansible_inventory" {
    commands = ["apply"]
    execute  = ["bash", "${get_terragrunt_dir()}/../../scripts/generate-inventory.sh", "prod", get_terragrunt_dir()]
  }
}

inputs = {
  environment      = "prod"
  network_cidr     = "10.10.3.0/24"
  network_gateway  = "10.10.3.1"
  control_plane_ips = ["10.10.3.11", "10.10.3.12", "10.10.3.13"]
  worker_ips        = ["10.10.3.21", "10.10.3.22", "10.10.3.23"]
}
