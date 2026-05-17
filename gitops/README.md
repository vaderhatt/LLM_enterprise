# gitops

GitOps live-state repository layout for RKE2 clusters.

## Layout

- `clusters/dev`, `clusters/stage`, and `clusters/prod` are environment entrypoints.
- `infrastructure` contains platform services and cluster-wide dependencies.
- `apps` contains product/application workloads.

Each environment entrypoint has its own `infrastructure` overlay. Shared infrastructure lives in `infrastructure`, while environment-specific values such as Dashboard DNS names are patched from `clusters/<env>/infrastructure`.

Key platform infrastructure components currently include:

- `infrastructure/ingress` for Flux-managed ingress-nginx
- `infrastructure/cilium` for post-bootstrap Cilium resources; RKE2 installs the base Cilium CNI before Flux starts
- `infrastructure/cert-manager` for certificate automation and the lab `selfsigned` issuer
- `infrastructure/kubernetes-dashboard` for Dashboard, ingress, and access token resources

## Apply Manually

Before Flux is bootstrapped, you can validate or apply the cluster entrypoint with:

```bash
kubectl kustomize clusters/dev
kubectl apply -k clusters/dev
```

Most directories are intentionally skeletal placeholders. Add real manifests beneath each component directory and list them in that component's `kustomization.yaml`.