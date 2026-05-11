# ingress

Ingress controller for platform services and applications.

This component installs ingress-nginx from the upstream bare-metal manifest and provides the `nginx` `IngressClass` expected by platform add-ons such as Kubernetes Dashboard.

The controller is configured with `hostNetwork` and `hostPort` for ports 80 and 443 so lab services can be reached directly on node IPs without a separate load balancer.

Validate before applying:

```bash
kubectl kustomize gitops/infrastructure/ingress
```