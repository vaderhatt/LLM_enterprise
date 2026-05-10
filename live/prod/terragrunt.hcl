include {
  path = find_in_parent_folders()
}

terraform {
  source = "../..//terraform"
}

inputs = {
  environment      = "prod"
  network_name     = "rke2-net"
  network_cidr     = "10.10.3.0/24"
  network_gateway  = "10.10.3.1"
  control_plane_ips = ["10.10.3.11", "10.10.3.12", "10.10.3.13"]
  worker_ips        = ["10.10.3.21", "10.10.3.22", "10.10.3.23"]

  control_plane_vm = {
    cpus         = 2
    memory_mib   = 4096
    disk_size_gb = 20
  }

  worker_vm = {
    cpus         = 2
    memory_mib   = 2048
    disk_size_gb = 10
  }
}
