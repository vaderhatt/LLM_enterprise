include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../..//terraform"

  after_hook "generate_ansible_inventory" {
    commands = ["apply"]
    execute  = ["bash", "${get_terragrunt_dir()}/../../scripts/generate-inventory.sh", "dev", get_terragrunt_dir()]
  }
}

inputs = {
  environment      = "dev"
  network_cidr     = "10.10.1.0/24"
  network_gateway  = "10.10.1.1"
  control_plane_ips = ["10.10.1.11", "10.10.1.12", "10.10.1.13"]
  worker_ips        = ["10.10.1.21", "10.10.1.22", "10.10.1.23"]
}
