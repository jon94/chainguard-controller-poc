#!/bin/bash

# Complete demo flow for Chainguard interview
# This script demonstrates the image digest compliance monitoring

set -e

echo "🎭 Chainguard Image Policy Controller Demo"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

demo_step() {
    echo -e "${BLUE}📍 Step $1: $2${NC}"
    echo ""
}

wait_for_input() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read
}

demo_step "1" "Setting up demo namespace and labels"
kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace demo monitored=true --overwrite
kubectl label namespace default monitored=true --overwrite

wait_for_input

demo_step "2" "Deploying ImagePolicy to monitor jonlimpw/demo-app"
kubectl apply -f "$(dirname "$0")/../controller/config/samples/demo-imagepolicy.yaml"

echo "📋 ImagePolicy created:"
kubectl get imagepolicy -o wide

wait_for_input

demo_step "3" "Deploying a non-compliant application (using tag instead of digest)"
kubectl apply -f "$(dirname "$0")/../controller/config/samples/demo-deployment.yaml"

echo "📋 Deployments created:"
kubectl get deployments -A -l app=cg-demo

wait_for_input

demo_step "4" "Checking compliance status (should show non-compliant)"
echo "⏳ Waiting for controller to analyze deployments (10s check interval)..."
sleep 15

echo "📊 ImagePolicy Status:"
kubectl get imagepolicy jonlimpw-demo-policy -o yaml | grep -A 20 "status:"

echo ""
echo "🚨 Events (should show non-compliance warnings):"
kubectl get events --field-selector involvedObject.kind=ImagePolicy

wait_for_input

demo_step "5" "Demonstrating real-time monitoring"
echo "🔄 The controller continuously monitors for changes..."
echo "📈 Current compliance metrics:"
kubectl get imagepolicy jonlimpw-demo-policy -o jsonpath='{.status.complianceStatus}' && echo ""
kubectl get imagepolicy jonlimpw-demo-policy -o jsonpath='{.status.compliantDeployments}/{.status.totalDeployments}' && echo " deployments compliant"

wait_for_input

demo_step "6" "Simulating image update (push new version to DockerHub)"
echo "💡 In a real scenario, you would:"
echo "   1. Build and push a new version via GitHub Actions or manually:"
echo "      docker build -t jonlimpw/cg-demo:v2.0.0 . && docker push jonlimpw/cg-demo:v2.0.0"
echo "   2. The controller would detect the new digest within 10 seconds"
echo "   3. Existing deployments would be marked as non-compliant"
echo "   4. Update deployments to use new digest for compliance"

wait_for_input

demo_step "7" "Viewing detailed compliance information"
echo "📋 Detailed deployment status:"
kubectl get imagepolicy jonlimpw-demo-policy -o jsonpath='{.status.monitoredDeployments}' | jq '.'

echo ""
echo "🔍 Controller logs (recent activity):"
kubectl logs -n chainguard-controller-system deployment/chainguard-controller-controller-manager -c manager --tail=20

wait_for_input

echo -e "${GREEN}✅ Demo Complete!${NC}"
echo ""
echo "🎯 Key Takeaways:"
echo "   • Controller monitors DockerHub for latest image digests"
echo "   • Deployments using tags (not digests) are flagged as non-compliant"
echo "   • Real-time compliance tracking with detailed status reporting"
echo "   • Kubernetes events provide audit trail of violations"
echo "   • Extensible to support image signing and attestation verification"
echo ""
echo "🔮 Future Extensions:"
echo "   • Cosign signature verification"
echo "   • SLSA provenance attestation checking"
echo "   • Admission controller integration"
echo "   • Policy-as-code with OPA/Gatekeeper"
echo ""
echo "🧹 Cleanup:"
echo "   kubectl delete -f controller/config/samples/"
echo "   kubectl delete namespace demo"
