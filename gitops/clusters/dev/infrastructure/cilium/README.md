# cilium

Post-bootstrap Cilium resources for the dev cluster.

The base Cilium CNI is installed by RKE2 during Ansible bootstrap, before Flux is available. Use this directory for Cilium resources that can be reconciled after cluster networking is already running.