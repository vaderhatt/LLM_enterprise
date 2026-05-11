# kubernetes-dashboard

Kubernetes Dashboard managed by Flux/Kustomize.

This component expects:

- `ingress-nginx` from `gitops/infrastructure/ingress`
- cert-manager and the `selfsigned` ClusterIssuer from `gitops/infrastructure/cert-manager`

Default host:

```text
dashboard.rke2.local
```

Point that hostname to an ingress node IP with DNS or `/etc/hosts`.

Get the login token:

```bash
kubectl -n kubernetes-dashboard get secret admin-user -o jsonpath='{.data.token}' | base64 -d
```

Validate before applying:

```bash
kubectl kustomize gitops/infrastructure/kubernetes-dashboard
```