# gitops

GitOps live-state repository layout for RKE2 clusters.

## Layout

- `clusters/dev`, `clusters/stage`, and `clusters/prod` are environment entrypoints.
- `infrastructure` contains platform services and cluster-wide dependencies.
- `apps` contains product/application workloads.

## Apply Manually

Before Flux is bootstrapped, you can validate or apply the cluster entrypoint with:

```bash
kubectl kustomize clusters/dev
kubectl apply -k clusters/dev
```

Most directories are intentionally skeletal placeholders. Add real manifests beneath each component directory and list them in that component's `kustomization.yaml`.