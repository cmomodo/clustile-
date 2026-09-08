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
  --wait
```

## Game Hub chart

The `charts/` directory is for Helm charts that this repository owns. When the
Game Hub chart is created, its `templates/` directory should contain the Game
Hub Deployment, Service, and Ingress. It should not contain Traefik's resources.
