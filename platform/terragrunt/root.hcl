remote_state {
  backend = "local"
  config = {
    path = "${get_terragrunt_dir()}/terraform.tfstate"
  }
}

locals {
  project_root        = dirname(dirname(find_in_parent_folders("root.hcl")))
  ssh_public_key_file = get_env("SSH_PUBLIC_KEY_FILE", "${local.project_root}/ansible/.ssh/id_ed25519.pub")
}

inputs = {
  data_dir     = "/mnt/raid1/LLM_enterprise_storage"
  storage_pool = "rke2-storage"
  network_name = "rke2-net"
  ssh_public_key = trimspace(file(local.ssh_public_key_file))

  control_plane_vm = {
    cpus         = 2
    memory_mib   = 8092
    disk_size_gb = 50
  }

  worker_vm = {
    cpus         = 8
    memory_mib   = 16536
    disk_size_gb = 50
  }
}