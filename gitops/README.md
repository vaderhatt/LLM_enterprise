# gitops

GitOps live-state repository layout for the lab RKE2 cluster.

## Layout

- `clusters/lab` is the cluster entrypoint.
- `infrastructure` contains platform services and cluster-wide dependencies.
- `apps` contains product/application workloads.

## Apply Manually

Before Flux is bootstrapped, you can validate or apply the cluster entrypoint with:

```bash
kubectl kustomize clusters/lab
kubectl apply -k clusters/lab
```

Most directories are intentionally skeletal placeholders. Add real manifests beneath each component directory and list them in that component's `kustomization.yaml`.