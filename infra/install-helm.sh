#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="${1:-gamehub38}"
REGION="${2:-us-east-1}"

echo "=========================================="
echo "Installing Helm Releases"
echo "=========================================="
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo ""

# Get Terraform outputs
echo "📋 Retrieving Terraform outputs..."
cd "$SCRIPT_DIR"
ROLE_ARN=$(terraform output -raw aws_load_balancer_controller_role_arn)
CONTROLLER_VERSION=$(terraform output -raw aws_load_balancer_controller_chart_version)
echo "   Role ARN: $ROLE_ARN"
echo "   Chart Version: $CONTROLLER_VERSION"
echo ""

# 1. Add Helm repositories
echo "📦 Adding Helm repositories..."
helm repo add eks https://aws.github.io/eks-charts
helm repo add traefik https://traefik.github.io/charts
helm repo update

# 2. Install AWS Load Balancer Controller
echo ""
echo "🔧 Installing AWS Load Balancer Controller..."
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.resourcesVpcConfig.vpcId' --output text)

# Apply ServiceAccount and annotate with IAM role from Terraform
kubectl apply -f "$SCRIPT_DIR/k8s/addons/aws-load-balancer-controller/serviceaccount.yaml"
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
  "eks.amazonaws.com/role-arn=$ROLE_ARN" --overwrite

# Install with pinned version from Terraform
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --version "$CONTROLLER_VERSION" \
  -n kube-system \
  -f "$SCRIPT_DIR/k8s/addons/aws-load-balancer-controller/values.yaml" \
  --set clusterName="$CLUSTER_NAME" \
  --set region="$REGION" \
  --set vpcId="$VPC_ID" \
  --wait --timeout=5m

echo "✅ AWS Load Balancer Controller installed (version $CONTROLLER_VERSION)"

# 3. Install Traefik
echo ""
echo "🚀 Installing Traefik Ingress Controller..."
helm install traefik traefik/traefik \
  -n kube-system \
  -f "$SCRIPT_DIR/k8s/addons/traefik/values.yaml" \
  --wait --timeout=5m

echo "✅ Traefik installed"

# 4. Get Traefik's external URL
echo ""
echo "=========================================="
echo "✅ All Helm releases installed successfully!"
echo "=========================================="
echo ""
echo "📊 Status:"
kubectl get svc -n kube-system traefik -o wide

# Wait for NLB to get hostname
echo ""
echo "⏳ Waiting for NLB hostname to be assigned (this may take 1-2 minutes)..."
for i in {1..120}; do
  TRAEFIK_HOST=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
  if [ ! -z "$TRAEFIK_HOST" ]; then
    echo ""
    echo "🎉 Traefik NLB Ready!"
    echo "   Hostname: $TRAEFIK_HOST"
    echo ""
    echo "📍 Your app URL: http://$TRAEFIK_HOST"
    break
  fi
  echo -n "."
  sleep 2
done

echo ""
echo "Done! The app should be accessible via the Traefik NLB."
echo ""
