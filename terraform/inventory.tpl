[${environment}_controlplane]
%{ for name, node in control_plane_nodes ~}
${node.name} ansible_host=${node.ip_address} ansible_user=${ansible_user} ansible_ssh_private_key_file=${ansible_ssh_private_key_file}
%{ endfor ~}

[${environment}_worker]
%{ for name, node in worker_nodes ~}
${node.name} ansible_host=${node.ip_address} ansible_user=${ansible_user} ansible_ssh_private_key_file=${ansible_ssh_private_key_file}
%{ endfor ~}

[controlplane:children]
${environment}_controlplane

[worker:children]
${environment}_worker

[${environment}_rke2_servers:children]
${environment}_controlplane

[${environment}_rke2_agents:children]
${environment}_worker

[${environment}_rke2_cluster:children]
${environment}_rke2_servers
${environment}_rke2_agents

[${environment}:children]
${environment}_rke2_cluster

[rke2_servers:children]
${environment}_rke2_servers

[rke2_agents:children]
${environment}_rke2_agents

[rke2_cluster:children]
rke2_servers
rke2_agents

[all:vars]
ansible_python_interpreter=/usr/bin/python3
