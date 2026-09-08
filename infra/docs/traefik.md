# Kubernetes layout

This directory separates third-party cluster add-ons from Helm charts owned by
this repository.

```text
k8s/
├── addons/
│   └── traefik/
│       └── values.yaml
└── charts/
    └── gamehub/              # Add when the application chart is created
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── deployment.yaml
            ├── service.yaml
            └── ingress.yaml
```

## Traefik

Traefik is a third-party Helm chart. Its upstream chart already contains its
Deployment, Service, RBAC, CRDs, and other templates. This repository therefore
stores only the project-specific overrides in `addons/traefik/values.yaml`.

The request path is:

```text
Internet -> controller-managed NLB -> Traefik Service/Pods
         -> application ClusterIP Service -> application Pods
```

Here, "application Service" means a Kubernetes `ClusterIP` Service. The NLB is
not declared as an `aws_lb` resource: the AWS Load Balancer Controller creates
and reconciles it from Traefik's `LoadBalancer` Service. A separate Terraform
NLB would have no Kubernetes-managed target registrations and would duplicate
the controller-managed load balancer.

Render the resources locally before installation:

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update traefik

helm template traefik traefik/traefik \
  --version 41.5.0 \
  --namespace traefik \
  --values infra/k8s/addons/traefik/values.yaml
```

After EKS has Ready worker nodes and the AWS Load Balancer Controller is
installed, install Traefik with:

```bash
helm upgrade --install traefik traefik/traefik \
  --version 41.5.0 \
  --namespace traefik \
  --create-namespace \
  --values infra/k8s/addons/traefik/values.yaml \
  --set-string "service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-security-groups=$(terraform -chdir=infra output -raw nlb_security_group_id)" \
  --set-string "service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-attributes=load_balancing.cross_zone.enabled=true\,access_logs.s3.enabled=true\,access_logs.s3.bucket=$(terraform -chdir=infra output -raw nlb_access_log_bucket)\,access_logs.s3.prefix=nlb" \
  --wait
```

The two dynamic overrides connect the Terraform-managed
`aws_security_group.lb_sg` and `aws_s3_bucket.lb_logs` resources to the NLB
created by the controller. The three `aws_subnet.public` instances are selected
automatically through their `kubernetes.io/role/elb = 1` tags.

### Why keep NLB access logs in S3?

The bucket provides durable request evidence outside the cluster. It helps with
incident investigation, TLS client and handshake troubleshooting, traffic
analysis, and audit/retention requirements even if a Pod or node disappears.
The bucket is private, encrypted with SSE-S3, limited to ELB log delivery from
this account and Region, and expires the `nlb/` log prefix after 90 days.

NLB access logging records TLS listener traffic; it is not an application HTTP
request log. Keep Traefik application/access logs as well when URL, status code,
or routing details are required. If the NLB has only a TCP port 80 listener,
the S3 bucket will not receive useful NLB access-log records.

## Game Hub chart

The `charts/` directory is for Helm charts that this repository owns. When the
Game Hub chart is created, its `templates/` directory should contain the Game
Hub Deployment, Service, and Ingress. It should not contain Traefik's resources.
