global
  log /dev/log local0
  log /dev/log local1 notice
  daemon
  maxconn 4096

defaults
  log global
  mode tcp
  option tcplog
  option dontlognull
  timeout connect 5s
  timeout client 50s
  timeout server 50s

frontend rke2_api
  bind *:6443
  default_backend rke2_api_servers

backend rke2_api_servers
  balance roundrobin
  option tcp-check
%{ for name, node in control_plane_nodes ~}
  server ${name} ${node.ip}:6443 check
%{ endfor ~}

frontend rke2_registration
  bind *:9345
  default_backend rke2_registration_servers

backend rke2_registration_servers
  balance roundrobin
  option tcp-check
%{ for name, node in control_plane_nodes ~}
  server ${name} ${node.ip}:9345 check
%{ endfor ~}

frontend ingress_http
  bind *:80
  default_backend ingress_http_servers

backend ingress_http_servers
  balance roundrobin
  option tcp-check
%{ for name, node in ingress_nodes ~}
  server ${name} ${node.ip}:80 check
%{ endfor ~}

frontend ingress_https
  bind *:443
  default_backend ingress_https_servers

backend ingress_https_servers
  balance roundrobin
  option tcp-check
%{ for name, node in ingress_nodes ~}
  server ${name} ${node.ip}:443 check
%{ endfor ~}