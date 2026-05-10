include {
  path = find_in_parent_folders()
}

terraform {
  source = "../..//terraform"
}

inputs = {
  environment      = "dev"
  storage_pool     = "rke2-storage"
  network_name     = "rke2-net"
  network_cidr     = "10.10.1.0/24"
  network_gateway  = "10.10.1.1"
  control_plane_ips = ["10.10.1.11", "10.10.1.12", "10.10.1.13"]
  worker_ips        = ["10.10.1.21", "10.10.1.22", "10.10.1.23"]

  control_plane_vm = {
    cpus         = 2
    memory_mib   = 4096
    disk_size_gb = 50
  }

  worker_vm = {
    cpus         = 2
    memory_mib   = 16536
    disk_size_gb = 50
  }
}
