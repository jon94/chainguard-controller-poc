#!/bin/bash

# Auto-Remediation Demo Script for Chainguard Controller

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

demo_step() {
    echo -e "${BLUE}📍 Step $1: $2${NC}"
    echo ""
}

wait_for_input() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read
}

echo -e "${PURPLE}🤖 Chainguard Controller - Auto-Remediation Demo${NC}"
echo "=================================================="
echo ""
echo "This demo shows how the controller can automatically fix"
echo "non-compliant deployments when they have automation:true label"
echo ""

wait_for_input

demo_step "1" "Deploy applications with different automation settings"
echo "Deploying:"
echo "  • auto-remediated-app (automation:true) - Will be auto-fixed"
echo "  • manual-app (no automation label) - Requires manual fix"
echo ""

kubectl apply -f "$(dirname "$0")/../controller/config/samples/auto-remediation-demo.yaml"

echo "📋 Deployments created:"
kubectl get deployments -n demo -l app=cg-demo

wait_for_input

demo_step "2" "Check initial compliance status"
echo "⏳ Waiting for controller to analyze deployments..."
sleep 15

echo "📊 Compliance Status:"
./scripts/check-compliance.sh jonlimpw-demo-policy demo

wait_for_input

demo_step "3" "Watch auto-remediation in action"
echo "🤖 The controller should automatically fix the deployment with automation:true"
echo "📊 Let's watch the events and deployment changes..."
echo ""

echo "Events (watch for AutoRemediated):"
kubectl get events -n demo --sort-by='.lastTimestamp' | tail -10

echo ""
echo "Deployment Images:"
kubectl get deployments -n demo -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.template.spec.containers[0].image}{"\n"}{end}'

wait_for_input

demo_step "4" "Verify auto-remediation results"
echo "📊 Final Compliance Status:"
./scripts/check-compliance.sh jonlimpw-demo-policy demo

echo ""
echo "🔍 Check deployment images again:"
kubectl get deployments -n demo -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.template.spec.containers[0].image}{"\n"}{end}'

echo ""
echo "📋 Recent Events:"
kubectl get events -n demo --sort-by='.lastTimestamp' | grep -E "(AutoRemediated|NonCompliantImage)" | tail -5

wait_for_input

demo_step "5" "Demonstrate the difference"
echo -e "${GREEN}✅ Auto-Remediated Deployment:${NC}"
echo "   • Had automation:true label"
echo "   • Controller automatically updated image to use digest"
echo "   • Now compliant without manual intervention"
echo ""
echo -e "${RED}❌ Manual Deployment:${NC}"
echo "   • No automation label"
echo "   • Still using tag-based image"
echo "   • Requires manual remediation"
echo ""

echo "🎯 Key Benefits:"
echo "   • Zero-touch compliance for critical workloads"
echo "   • Selective automation based on labels"
echo "   • Full audit trail of automatic changes"
echo "   • Enterprise-grade self-healing capabilities"

echo ""
echo -e "${GREEN}🎉 Auto-Remediation Demo Complete!${NC}"
echo ""
echo "🔧 To enable auto-remediation on any deployment:"
echo "   kubectl label deployment DEPLOYMENT_NAME automation=true -n NAMESPACE"
echo ""
echo "🧹 Cleanup:"
echo "   kubectl delete -f controller/config/samples/auto-remediation-demo.yaml"
