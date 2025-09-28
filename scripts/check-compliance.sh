#!/bin/bash

# Check ImagePolicy compliance status in a human-readable format

POLICY_NAME=${1:-"jonlimpw-demo-policy"}
NAMESPACE=${2:-"demo"}

echo "🔍 Checking compliance for ImagePolicy: $POLICY_NAME in namespace: $NAMESPACE"
echo "=================================================================="

# Get overall status
COMPLIANCE_STATUS=$(kubectl get imagepolicy $POLICY_NAME -n $NAMESPACE -o jsonpath='{.status.complianceStatus}' 2>/dev/null)
TOTAL=$(kubectl get imagepolicy $POLICY_NAME -n $NAMESPACE -o jsonpath='{.status.totalDeployments}' 2>/dev/null)
COMPLIANT=$(kubectl get imagepolicy $POLICY_NAME -n $NAMESPACE -o jsonpath='{.status.compliantDeployments}' 2>/dev/null)
LATEST_DIGEST=$(kubectl get imagepolicy $POLICY_NAME -n $NAMESPACE -o jsonpath='{.status.latestDigest}' 2>/dev/null)

if [ -z "$COMPLIANCE_STATUS" ]; then
    echo "❌ ImagePolicy '$POLICY_NAME' not found in namespace '$NAMESPACE'"
    exit 1
fi

echo "📊 Overall Status: $COMPLIANCE_STATUS"
echo "📈 Compliance: $COMPLIANT/$TOTAL deployments compliant"
echo "🔗 Latest Digest: ${LATEST_DIGEST:0:20}..."
echo ""

# Get deployment details
echo "📋 Deployment Details:"
echo "====================="

kubectl get imagepolicy $POLICY_NAME -n $NAMESPACE -o jsonpath='{.status.monitoredDeployments[*]}' | jq -r '
  if type == "array" then
    .[] | 
    if .isCompliant then
      "✅ \(.namespace)/\(.name) - COMPLIANT (digest: \(.currentDigest[0:20])...)"
    else
      "❌ \(.namespace)/\(.name) - NON-COMPLIANT (using: \(.currentDigest))"
    end
  else
    if .isCompliant then
      "✅ \(.namespace)/\(.name) - COMPLIANT (digest: \(.currentDigest[0:20])...)"
    else
      "❌ \(.namespace)/\(.name) - NON-COMPLIANT (using: \(.currentDigest))"
    end
  end
'

echo ""
echo "🔧 To fix non-compliant deployments, use:"
echo "kubectl set image deployment/DEPLOYMENT_NAME CONTAINER_NAME=jonlimpw/cg-demo@$LATEST_DIGEST -n NAMESPACE"
