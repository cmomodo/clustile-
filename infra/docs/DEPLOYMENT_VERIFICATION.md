# Deployment Verification Guide

After deploying your gamehub app, use these commands to verify it's running.

## Deploy the app and port-forward

Run these commands from the project root (`kube_game`). The current
`infra/install-helm.sh` installs the controllers and the GameHub application
chart. If the cluster was set up before that script included the application,
use the install command below to restore it.

If `kubectl get svc -A` only shows `kubernetes` in the `default` namespace and
controller services in `kube-system`, the GameHub service is missing. The
`kubernetes` service is the Kubernetes API, not the app.

```bash
# Connect to the current cluster (refresh this after recreating EKS).
aws eks update-kubeconfig --region us-east-1 --name gamehub38
kubectl get nodes

# Check whether the app exists in another namespace before installing it.
kubectl get svc -A
helm list -A

# Install or update the app in default.
helm upgrade --install gamehub ./infra/k8s/gamehub --namespace default
kubectl rollout status deployment/gamehub --namespace default --timeout=180s
kubectl get pods,svc --namespace default -l app=gamehub

# Keep this command running while using the app.
kubectl port-forward --namespace default svc/gamehub 3000:80
```

Open http://localhost:3000. Here `3000` is the local port and `80` is the service
port; the service forwards traffic to port `3000` in the app container. Stop
forwarding with Ctrl+C. If local port 3000 is occupied, use `8080:80` and open
http://localhost:8080 instead.

If the app already exists in another namespace, use that namespace in the
rollout and port-forward commands instead of installing another copy.

Port-forwarding needs a running app pod, but does not require an Ingress or an
external load balancer. Traefik's external IP can remain `<pending>` while you
test the app locally.

If rollout fails, inspect the pods and events:

```bash
kubectl get pods --namespace default -l app=gamehub
kubectl describe pods --namespace default -l app=gamehub
kubectl logs --namespace default -l app=gamehub --all-containers=true
```

For `ImagePullBackOff`, check that the ECR repository and image tag in
`infra/k8s/gamehub/values.yaml` exist and that the nodes can pull the image.

## Quick Checks

### 1. **Run the automatic verification script** (recommended)
```bash
./verify-deployment.sh [namespace]
# Example with default namespace:
./verify-deployment.sh default
```

This checks:
- Pod status and readiness
- Service connectivity
- Ingress provisioning
- Pod logs for errors
- HTTP endpoint availability

### 2. **Manual verification steps**

**Check pods are running:**
```bash
kubectl get pods -l app=gamehub -o wide
```
Expected: 2 pods with status "Running"

**Check service:**
```bash
kubectl get svc gamehub
```
Expected: ClusterIP service on port 80 → 3000

**Check Ingress:**
```bash
kubectl get ingress gamehub -o wide
```
Expected: ADDRESS will populate within 1-2 minutes

**Get the access URL:**
```bash
kubectl get ingress gamehub -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**View pod logs:**
```bash
kubectl logs -l app=gamehub --all-containers=true
```

### 3. **Test the app**

**Option A: Port-forward (works immediately after pod starts)**
```bash
kubectl port-forward svc/gamehub 3000:80
```
Then visit: `http://localhost:3000`

**Option B: Via Ingress hostname (after DNS resolves, usually 1-2 min)**
```bash
INGRESS_HOST=$(kubectl get ingress gamehub -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$INGRESS_HOST
```

**Option C: Quick HTTP check**
```bash
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://gamehub/
```

## Architecture

```
Your Container (port 3000)
         ↓
  Service (port 80 → targetPort 3000)
         ↓
  Ingress (Traefik)
         ↓
  NLB (Load Balancer)
         ↓
  External Access (http://gamehub-xxx.elb.amazonaws.com)
```

## Troubleshooting

| Issue | Command | Solution |
|-------|---------|----------|
| Pods stuck in Pending | `kubectl describe pod <pod-name>` | Check node resources and scheduling |
| Pods crashing | `kubectl logs <pod-name>` | Check app startup errors |
| No Ingress IP | `kubectl describe ingress gamehub` | Wait 2-3 min, may be provisioning NLB |
| Connection refused | `kubectl port-forward svc/gamehub 3000:80` | Test port-forward first, then debug ingress |
| HTTP 404 from Traefik | `kubectl get ingress,svc,pods -n default` | Install the GameHub chart if its Ingress or Service is missing; otherwise check the Ingress class and path |

## Cleanup after testing

```bash
# Stop port-forward (Ctrl+C)
# To delete everything:
helm uninstall gamehub
```
