# AWS Load Balancer Controller

This cluster add-on manages the NLB requested by Traefik's LoadBalancer Service.
GameHub keeps a Traefik Ingress and a ClusterIP Service:

```text
Internet -> NLB -> Traefik -> GameHub Service -> GameHub pods
```

[`serviceaccount.yaml`](../k8s/addons/aws-load-balancer-controller/serviceaccount.yaml)
belongs in `kube-system`, separately from the GameHub Helm release.
[`values.yaml`](../k8s/addons/aws-load-balancer-controller/values.yaml) configures
the upstream `eks/aws-load-balancer-controller` chart to use that existing account.

[`infra/install-helm.sh`](../install-helm.sh) applies the ServiceAccount, annotates it with the controller
IAM role, and passes these values to the controller Helm release. It supplies the
cluster name, AWS region, and VPC ID at installation time.

For IRSA, the cluster's IAM OIDC provider and the controller IAM role with the
official controller permissions must exist. The installer's embedded IAM policy
still needs replacing with the official policy before deploying: ELB IAM actions
use the `elasticloadbalancing:` prefix, rather than `elbv2:`.

Moving these files does not migrate an existing Helm release. If GameHub already
owns the ServiceAccount in a deployed release, preserve it before upgrading that
release so the controller does not lose its identity.
