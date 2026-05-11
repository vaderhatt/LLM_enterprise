# cert-manager

Certificate manager installation and cluster issuers.

This component installs cert-manager and creates a `selfsigned` `ClusterIssuer` for lab TLS. Replace or extend this with ACME, Vault, or an internal CA issuer before production use.

Validate before applying:

```bash
kubectl kustomize gitops/infrastructure/cert-manager
```