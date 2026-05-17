# ingress

Ingress controller for platform services and applications.

RKE2's bundled `rke2-ingress-nginx` add-on is disabled by the platform RKE2 configuration. This component installs and manages ingress-nginx through Flux/IaC.

The controller is pinned to `worker1` and uses host ports 80 and 443, so services can be reached directly on `worker1` without a separate load balancer.

Validate before applying:

```bash
kubectl kustomize gitops/clusters/stage/infrastructure/ingress
```