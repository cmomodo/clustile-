#!/bin/bash

set -e

CLUSTER_NAME="${1:-gamehub38}"
REGION="${2:-us-east-1}"
ACCOUNT_ID="${3:-$(aws sts get-caller-identity --query Account --output text)}"

echo "=========================================="
echo "Tearing Down Helm Releases"
echo "=========================================="
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo ""

# 1. Uninstall Helm releases
echo "🗑️  Removing Helm releases..."

echo "   Uninstalling Traefik..."
helm uninstall traefik -n kube-system 2>/dev/null || echo "   (Not installed)"

echo "   Uninstalling AWS Load Balancer Controller..."
helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || echo "   (Not installed)"

# Wait for pods to terminate
echo ""
echo "⏳ Waiting for pods to terminate..."
sleep 10

# 2. Clean up remaining resources
echo ""
echo "🧹 Cleaning up remaining resources..."

# Delete webhook services if they exist
echo "   Removing webhook services..."
kubectl delete service aws-load-balancer-webhook-service -n kube-system 2>/dev/null || true
kubectl delete deployment aws-load-balancer-controller -n kube-system 2>/dev/null || true

# 3. Remove IAM role and policy
echo ""
echo "🔐 Cleaning up IAM resources..."

ROLE_NAME="AWSLoadBalancerControllerRole-${CLUSTER_NAME}"

# Check if role exists
if aws iam get-role --role-name "$ROLE_NAME" --region $REGION 2>/dev/null; then
  echo "   Removing inline policies from role..."
  aws iam delete-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name AWSLoadBalancerControllerPolicy \
    --region $REGION 2>/dev/null || true

  echo "   Deleting IAM role $ROLE_NAME..."
  aws iam delete-role \
    --role-name "$ROLE_NAME" \
    --region $REGION 2>/dev/null || true
  echo "   ✅ Role deleted"
else
  echo "   (Role not found)"
fi

echo ""
echo "=========================================="
echo "✅ Teardown complete!"
echo "=========================================="
echo ""
echo "Current state:"
kubectl get pods -n kube-system | grep -E "traefik|aws-load|NAME" || echo "No Helm-managed pods found"
echo ""
echo "To reinstall, run: ./install-helm.sh $CLUSTER_NAME $REGION"
echo ""
