#!/bin/bash

echo "🔍 Chainguard Controller: Live Attestation Verification"
echo "======================================================="
echo ""

echo "This demo shows the controller's attestation verification in real-time."
echo "Watch for these key log messages:"
echo ""
echo "✅ 'Digest match - compliant' - Image uses latest digest"
echo "🔐 'Attestation verification failed/succeeded' - Rekor verification results"
echo "📊 'Deployment compliance status' - Final compliance decision"
echo ""

echo "Press Ctrl+C to stop watching logs..."
echo ""
echo "🔍 Controller Logs (Live):"
echo "=========================="

# Check if controller is running locally (make run) or in cluster
if pgrep -f "make run" > /dev/null; then
    echo "📍 Detected local controller (make run)"
    echo "Logs are integrated with the running process output."
    echo ""
    echo "To see live logs, run in another terminal:"
    echo "  tail -f /tmp/controller.log"
    echo ""
    echo "Or trigger a new reconciliation:"
    echo "  kubectl patch imagepolicy enterprise-attestation-policy -n demo -p '{\"metadata\":{\"annotations\":{\"demo/trigger\":\"$(date)\"}}}'"
    
elif kubectl get pods -n controller -l app.kubernetes.io/name=chainguard-controller &>/dev/null; then
    echo "📍 Detected cluster controller"
    kubectl logs -n controller -l app.kubernetes.io/name=chainguard-controller -f --tail=20
else
    echo "❌ Controller not found running locally or in cluster"
    echo ""
    echo "To start the controller locally:"
    echo "  cd controller && make run"
    echo ""
    echo "Or deploy to cluster:"
    echo "  kubectl apply -f controller/config/samples/controller-deployment.yaml"
fi

echo ""
echo "🎯 Key Verification Points:"
echo ""
echo "1. Latest Digest Check:"
echo "   • Controller fetches latest digest from DockerHub"
echo "   • Compares with deployment's current image digest"
echo ""
echo "2. Attestation Verification:"
echo "   • Extracts SHA256 digest from container image"
echo "   • Queries Rekor transparency log for attestations"
echo "   • Validates against policy requirements (issuer, type)"
echo ""
echo "3. Compliance Decision:"
echo "   • BOTH digest and attestation checks must pass"
echo "   • Tag-based images automatically fail attestation check"
echo "   • Only cryptographically verified images are compliant"
echo ""
echo "🏢 This demonstrates enterprise-grade supply chain security!"
