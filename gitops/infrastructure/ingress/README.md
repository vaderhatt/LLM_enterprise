# ingress

Ingress controller for platform services and applications.

This component installs ingress-nginx from the upstream bare-metal manifest and provides the `nginx` `IngressClass` expected by platform add-ons such as Kubernetes Dashboard.

Validate before applying:

```bash
kubectl kustomize gitops/infrastructure/ingress
```