# Helm Installation Guide

This guide explains how to install the AWS Load Balancer Controller, Traefik,
and GameHub Helm releases on your EKS cluster.

## Prerequisites

- EKS cluster running (e.g., `gamehub38`)
- `kubectl` configured and connected to the cluster
- `helm` installed (v3+)
- AWS CLI configured with appropriate credentials
- `jq` installed (for JSON parsing)

## Quick Start

### One-Command Installation

```bash
./install-helm.sh gamehub38 us-east-1
```

Or with explicit AWS account ID:
```bash
./install-helm.sh gamehub38 us-east-1 449095351082
```

This script will:
1. ✅ Add Helm repositories (EKS, Traefik)
2. ✅ Create IAM role for AWS Load Balancer Controller (with IRSA)
3. ✅ Install AWS Load Balancer Controller
4. ✅ Install Traefik Ingress Controller
5. ✅ Install GameHub and its Ingress
6. ✅ Output the Traefik NLB hostname

## What Gets Installed

### 1. AWS Load Balancer Controller

**What it does:**
- Manages NLB (Network Load Balancer) provisioning
- Bridges Kubernetes Services/Ingresses with AWS infrastructure
- Required for Traefik to get an external hostname

**Namespace:** `kube-system`

**IAM Setup:**
- The script creates an IAM role: `AWSLoadBalancerControllerRole-gamehub38`
- Uses IRSA (IAM Role for Service Accounts) for secure credential delegation
- No credentials stored in the cluster

### 2. Traefik Ingress Controller

**What it does:**
- Routes HTTP/HTTPS traffic to your Kubernetes services
- Creates an NLB to receive external traffic
- Reads Ingress resources to route traffic to apps

**Namespace:** `kube-system`

**Configuration:** Uses values from `k8s/addons/traefik/values.yaml`

## Manual Step-by-Step Installation

If you prefer to install manually:

```bash
# 1. Add repos
helm repo add eks https://aws.github.io/eks-charts
helm repo add traefik https://traefik.github.io/charts
helm repo update

# 2. Get cluster OIDC provider
CLUSTER_NAME=gamehub38
REGION=us-east-1
OIDC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.identity.oidc.issuer' --output text | cut -d '/' -f 5)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 3. Create IAM role (with trust policy for service account)
# ... [see trust-policy setup in script]

# 4. Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::${ACCOUNT_ID}:role/AWSLoadBalancerControllerRole-${CLUSTER_NAME}" \
  --set serviceAccount.create=true \
  --set awsRegion=$REGION

# 5. Install Traefik
helm install traefik traefik/traefik \
  -n kube-system \
  -f k8s/addons/traefik/values.yaml

# 6. Install GameHub (from the project root)
helm upgrade --install gamehub ./infra/k8s/gamehub \
  -n default --wait
```

## Troubleshooting

### AWS Load Balancer Controller pods are CrashLoopBackOff

**Issue:** Pods crash immediately or after a few seconds

**Check:**
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50
```

**Common errors:**
- `unable to initialize AWS cloud` → Missing or incorrect region
- `UnauthorizedOperation` → IAM role not properly attached
- `AccessDenied` → IAM role missing required permissions

**Fix:**
```bash
# Reinstall with correct IAM role and region
helm uninstall aws-load-balancer-controller -n kube-system
./install-helm.sh gamehub38 us-east-1
```

### Traefik service has no external IP

**Issue:** `kubectl get svc -n kube-system traefik` shows `<pending>` for EXTERNAL-IP

**This is normal** if AWS Load Balancer Controller isn't running. Once fixed, it may take 1-2 minutes for the NLB to be provisioned.

**Check status:**
```bash
# Monitor the controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f

# Check the service events
kubectl describe svc traefik -n kube-system
```

### Ingress resources are not getting an ADDRESS

**Issue:** `kubectl get ingress` shows empty ADDRESS column

**Check:**
1. Is Traefik running? `kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik`
2. Does Traefik service have external IP? `kubectl get svc -n kube-system traefik`
3. Check ingress status: `kubectl describe ingress gamehub`

## Verification

After installation, verify everything is working:

```bash
# 1. Check all components are running
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik

# 2. Check Traefik service
kubectl get svc -n kube-system traefik

# 3. Check your app's Ingress
kubectl get ingress gamehub

# 4. Get the hostname
TRAEFIK_HOST=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "App URL: http://$TRAEFIK_HOST"

# 5. Test access
curl http://$TRAEFIK_HOST
```

## Uninstallation

To remove the Helm releases:

```bash
# Remove Traefik
helm uninstall traefik -n kube-system

# Remove AWS Load Balancer Controller
helm uninstall aws-load-balancer-controller -n kube-system

# (Optional) Remove IAM role
aws iam detach-role-policy \
  --role-name AWSLoadBalancerControllerRole-gamehub38 \
  --policy-arn arn:aws:iam::aws:policy/AWSLoadBalancerControllerPolicy

aws iam delete-role --role-name AWSLoadBalancerControllerRole-gamehub38
```

## Complete Deployment Workflow

Once Helm releases are installed, verify your app:

```bash
# 1. Check if pods are running
kubectl get pods -l app=gamehub

# 2. Check if Ingress is provisioned
kubectl get ingress

# 3. Get external URL
kubectl get ingress gamehub -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# 4. Test access
curl http://$(kubectl get ingress gamehub -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

Or use the verification script:
```bash
./verify-deployment.sh default
```

## Architecture

```
Internet
   ↓
NLB (created by AWS LB Controller, managed by Traefik service)
   ↓
Traefik Pod (routes traffic)
   ↓
Ingress gamehub (routes to service based on path)
   ↓
Service gamehub (ClusterIP, port 80 → targetPort 3000)
   ↓
GameHub Pod (listening on port 3000)
```

## Notes

- The AWS Load Balancer Controller uses IRSA (IAM Role for Service Accounts) for security
- No AWS credentials are stored in the cluster
- The IAM role is only used by the controller's service account
- Traefik's values can be customized in `k8s/addons/traefik/values.yaml`
