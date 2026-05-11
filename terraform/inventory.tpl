[${environment}_controlplane]
%{ for name, node in control_plane_nodes ~}
${node.name} ansible_host=${node.ip_address}
%{ endfor ~}

[${environment}_worker]
%{ for name, node in worker_nodes ~}
${node.name} ansible_host=${node.ip_address}
%{ endfor ~}

[controlplane:children]
${environment}_controlplane

[worker:children]
${environment}_worker

[${environment}:children]
${environment}_controlplane
${environment}_worker

[rke2_servers:children]
${environment}_controlplane

[rke2_agents:children]
${environment}_worker

[rke2_cluster:children]
rke2_servers
rke2_agents

[all:vars]
ansible_python_interpreter=/usr/bin/python3
