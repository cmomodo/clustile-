#!/bin/bash

set -e

NAMESPACE="${1:-default}"
APP_NAME="gamehub"
TIMEOUT=300
ELAPSED=0

echo "=== Verifying Deployment: $APP_NAME in namespace: $NAMESPACE ==="

# 1. Check Pod Status
echo ""
echo "1️⃣ Checking Pod Status..."
kubectl get pods -n "$NAMESPACE" -l app="$APP_NAME" -o wide
while [ $(kubectl get pods -n "$NAMESPACE" -l app="$APP_NAME" -o jsonpath='{.items[*].status.phase}' | grep -o Running | wc -l) -lt 2 ]; do
  if [ $ELAPSED -gt $TIMEOUT ]; then
    echo "❌ Pods did not reach Running state within $TIMEOUT seconds"
    exit 1
  fi
  echo "   Waiting for pods to be Running..."
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done
echo "✅ All pods are Running"

# 2. Check Service Status
echo ""
echo "2️⃣ Checking Service Status..."
SERVICE_IP=$(kubectl get svc -n "$NAMESPACE" "$APP_NAME" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
SERVICE_TYPE=$(kubectl get svc -n "$NAMESPACE" "$APP_NAME" -o jsonpath='{.spec.type}' 2>/dev/null || echo "")
echo "   Service Type: $SERVICE_TYPE"
echo "   Cluster IP: $SERVICE_IP"
kubectl get svc -n "$NAMESPACE" "$APP_NAME" -o wide

# 3. Check Ingress Status
echo ""
echo "3️⃣ Checking Ingress Status..."
INGRESS_IP=$(kubectl get ingress -n "$NAMESPACE" "$APP_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
if [ -z "$INGRESS_IP" ]; then
  INGRESS_IP=$(kubectl get ingress -n "$NAMESPACE" "$APP_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
fi

if [ -z "$INGRESS_IP" ]; then
  echo "   ⏳ Ingress IP/Hostname not yet assigned (this may take a few minutes)"
else
  echo "   ✅ Ingress IP/Hostname: $INGRESS_IP"
fi
kubectl get ingress -n "$NAMESPACE" "$APP_NAME" -o wide 2>/dev/null || echo "   No Ingress found"

# 4. Check Pod Logs
echo ""
echo "4️⃣ Checking Pod Logs..."
POD=$(kubectl get pods -n "$NAMESPACE" -l app="$APP_NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ ! -z "$POD" ]; then
  echo "   Last 10 lines from $POD:"
  kubectl logs -n "$NAMESPACE" "$POD" --tail=10 2>/dev/null || echo "   Could not fetch logs"
fi

# 5. Port-forward test (optional)
echo ""
echo "5️⃣ Testing port-forward (if you want to test locally):"
echo "   Run: kubectl port-forward -n $NAMESPACE svc/$APP_NAME 3000:80"
echo "   Then visit: http://localhost:3000"

# 6. Direct URL test (if Ingress is ready)
if [ ! -z "$INGRESS_IP" ]; then
  echo ""
  echo "6️⃣ Testing direct access via Ingress:"
  echo "   URL: http://$INGRESS_IP"
  echo "   Attempting HTTP GET..."
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$INGRESS_IP" 2>/dev/null || echo "000")
  echo "   HTTP Response Code: $HTTP_CODE"
  if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ App is responding!"
  else
    echo "   ⏳ App may still be starting up or responding with $HTTP_CODE"
  fi
fi

echo ""
echo "=== Verification Complete ==="
