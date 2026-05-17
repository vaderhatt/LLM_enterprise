# external-secrets

External Secrets Operator is installed with Flux Helm resources. The
`external-secrets-vault-auth` service account is bound to `system:auth-delegator`
so Vault can validate Kubernetes service account tokens through TokenReview.