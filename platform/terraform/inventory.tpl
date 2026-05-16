[${environment}_controlplane]
%{ for name, node in control_plane_nodes ~}
${node.name} ansible_host=${node.ip_address}
%{ endfor ~}

[${environment}_worker]
%{ for name, node in worker_nodes ~}
${node.name} ansible_host=${node.ip_address}
%{ endfor ~}

[${environment}_load_balancer]
${load_balancer_node.name} ansible_host=${load_balancer_node.ip_address}

[${environment}_domain_controller]
${domain_controller_node.name} ansible_host=${domain_controller_node.ip_address}

[${environment}_vault]
${vault_node.name} ansible_host=${vault_node.ip_address}

[controlplane:children]
${environment}_controlplane

[worker:children]
${environment}_worker

[load_balancer:children]
${environment}_load_balancer

[domain_controller:children]
${environment}_domain_controller

[vault:children]
${environment}_vault

[${environment}:children]
${environment}_controlplane
${environment}_worker
${environment}_load_balancer
${environment}_domain_controller
${environment}_vault

[rke2_servers:children]
${environment}_controlplane

[rke2_agents:children]
${environment}_worker

[rke2_cluster:children]
rke2_servers
rke2_agents

[all:vars]
ansible_python_interpreter=/usr/bin/python3
rke2_api_endpoint=${load_balancer_node.ip_address}
rke2_api_hostname=${load_balancer_hostname}
coredns_environment=${environment}
coredns_domain=${internal_domain}
samba_ad_realm=${samba_ad_realm}
samba_ad_dns_zone=${lower(samba_ad_realm)}
samba_ad_netbios_domain=${samba_ad_netbios_domain}
samba_ad_dc_ip=${domain_controller_node.ip_address}
samba_ad_dc_hostname=${domain_controller_node.name}
vault_ip=${vault_node.ip_address}
vault_hostname=vault.${environment}.${internal_domain}
