# Deployment Verification Guide

After deploying your gamehub app, use these commands to verify it's running.

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
| HTTP 404 | Check container logs | App may not be handling `/` route |

## Cleanup after testing

```bash
# Stop port-forward (Ctrl+C)
# To delete everything:
helm uninstall gamehub
```
