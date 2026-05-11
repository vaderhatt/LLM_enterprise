[controlplane]
%{ for name, node in control_plane_nodes ~}
${node.name} ansible_host=${node.ip_address} ansible_user=${ansible_user} ansible_ssh_private_key_file=${ansible_ssh_private_key_file}
%{ endfor ~}

[worker]
%{ for name, node in worker_nodes ~}
${node.name} ansible_host=${node.ip_address} ansible_user=${ansible_user} ansible_ssh_private_key_file=${ansible_ssh_private_key_file}
%{ endfor ~}

[all:vars]
ansible_python_interpreter=/usr/bin/python3
