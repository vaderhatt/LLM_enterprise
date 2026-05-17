# vault-or-openbao

Vault is deployed outside the cluster by Ansible. This directory contains the
External Secrets store that points workloads at the environment Vault instance.

The `external-secrets/vault-ca` Secret and Vault Kubernetes auth backend are
configured by `platform/ansible/playbooks/configure-vault-kubernetes-auth.yml`
after RKE2 is available.