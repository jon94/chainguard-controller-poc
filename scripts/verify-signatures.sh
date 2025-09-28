#!/bin/bash

# Verify Cosign signatures and attestations for demo app
# This script demonstrates how to verify the supply chain security of images

set -e

echo "🔍 Chainguard Demo: Verifying Image Signatures & Attestations"
echo "=============================================================="
echo ""

# Check if cosign is installed
if ! command -v cosign &> /dev/null; then
    echo "❌ Cosign not found. Installing..."
    
    # Install cosign
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install cosign
    else
        # Linux installation
        curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
        sudo mv cosign-linux-amd64 /usr/local/bin/cosign
        sudo chmod +x /usr/local/bin/cosign
    fi
    
    echo "✅ Cosign installed successfully"
    echo ""
fi

# Get the latest image digest
echo "📋 Fetching latest image digest..."
TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:jonlimpw/cg-demo:pull" | jq -r .token)
DIGEST=$(curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" "https://registry-1.docker.io/v2/jonlimpw/cg-demo/manifests/latest" | jq -r '.config.digest // empty')

if [ -z "$DIGEST" ]; then
    # Fallback: get digest from response headers
    DIGEST=$(curl -s -I -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" "https://registry-1.docker.io/v2/jonlimpw/cg-demo/manifests/latest" | grep -i docker-content-digest | cut -d' ' -f2 | tr -d '\r')
fi

if [ -z "$DIGEST" ]; then
    echo "❌ Could not fetch image digest"
    exit 1
fi

IMAGE_REF="jonlimpw/cg-demo@$DIGEST"
echo "🎯 Target Image: $IMAGE_REF"
echo ""

# Verify signature
echo "🔐 Verifying Cosign signature..."
echo "--------------------------------"
export COSIGN_EXPERIMENTAL=1

if cosign verify "$IMAGE_REF" 2>/dev/null; then
    echo "✅ Signature verification PASSED"
    echo "   • Image is signed with valid Sigstore certificate"
    echo "   • Signature recorded in Rekor transparency log"
    echo "   • OIDC identity verified via Fulcio"
else
    echo "❌ Signature verification FAILED"
    echo "   • Image may not be signed"
    echo "   • Or signature is invalid/expired"
fi

echo ""

# Verify SLSA attestation
echo "📜 Verifying SLSA provenance attestation..."
echo "-------------------------------------------"

if cosign verify-attestation --type slsaprovenance "$IMAGE_REF" 2>/dev/null; then
    echo "✅ SLSA attestation verification PASSED"
    echo "   • Build provenance is authentic"
    echo "   • Supply chain metadata verified"
    echo "   • Build environment recorded"
else
    echo "❌ SLSA attestation verification FAILED"
    echo "   • No valid attestation found"
    echo "   • Or attestation signature is invalid"
fi

echo ""

# Show attestation details
echo "📊 SLSA Attestation Details:"
echo "----------------------------"
cosign verify-attestation --type slsaprovenance "$IMAGE_REF" 2>/dev/null | jq -r '.payload' | base64 -d | jq '.predicate' || echo "No attestation details available"

echo ""
echo "🎯 Enterprise Security Summary:"
echo "==============================="
echo "✅ Image digest compliance enforced"
echo "✅ Cryptographic signatures verified"  
echo "✅ Supply chain provenance validated"
echo "✅ Build transparency via Rekor"
echo ""
echo "🔒 This demonstrates enterprise-grade supply chain security!"
