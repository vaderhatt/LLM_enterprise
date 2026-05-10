include {
  path = find_in_parent_folders()
}

terraform {
  source = "../..//terraform"
}

inputs = {
  environment      = "stage"
  storage_pool     = "rke2-storage"
  network_name     = "rke2-net"
  network_cidr     = "10.10.2.0/24"
  network_gateway  = "10.10.2.1"
  control_plane_ips = ["10.10.2.11", "10.10.2.12", "10.10.2.13"]
  worker_ips        = ["10.10.2.21", "10.10.2.22", "10.10.2.23"]

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
