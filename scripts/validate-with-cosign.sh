#!/bin/bash

# Validate attestations using Cosign (when TUF issues are resolved)
# This shows how to verify both signatures and attestations

set -e

echo "🔍 Cosign Attestation Validation"
echo "================================"
echo ""

# Check if cosign is installed
if ! command -v cosign &> /dev/null; then
    echo "📥 Installing Cosign..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install cosign
    else
        curl -O -L "https://github.com/sigstore/cosign/releases/download/v2.2.4/cosign-linux-amd64"
        sudo mv cosign-linux-amd64 /usr/local/bin/cosign
        sudo chmod +x /usr/local/bin/cosign
    fi
    
    echo "✅ Cosign installed successfully"
    echo ""
fi

# Set experimental mode for keyless verification
export COSIGN_EXPERIMENTAL=1

# Get image digest
IMAGE="jonlimpw/cg-demo"
TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$IMAGE:pull" | jq -r .token)
DIGEST=$(curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" "https://registry-1.docker.io/v2/$IMAGE/manifests/latest" | jq -r '.config.digest // empty')

if [ -z "$DIGEST" ]; then
    DIGEST=$(curl -s -I -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" "https://registry-1.docker.io/v2/$IMAGE/manifests/latest" | grep -i docker-content-digest | cut -d' ' -f2 | tr -d '\r')
fi

IMAGE_REF="$IMAGE@$DIGEST"
echo "🎯 Target Image: $IMAGE_REF"
echo ""

echo "🔐 Cosign Verification Methods:"
echo "==============================="
echo ""

echo "1️⃣ Verify Signatures:"
echo "---------------------"
echo "Command: cosign verify $IMAGE_REF"
echo "Purpose: Verify cryptographic signatures"
echo ""

echo "2️⃣ Verify SLSA Attestations:"
echo "----------------------------"
echo "Command: cosign verify-attestation --type slsaprovenance $IMAGE_REF"
echo "Purpose: Verify SLSA provenance attestations"
echo ""

echo "3️⃣ Verify Custom Attestations:"
echo "------------------------------"
echo "Command: cosign verify-attestation --type custom $IMAGE_REF"
echo "Purpose: Verify custom attestation types"
echo ""

echo "4️⃣ Download and Inspect Attestations:"
echo "------------------------------------"
echo "Command: cosign download attestation $IMAGE_REF | jq '.payload' | base64 -d | jq '.'"
echo "Purpose: Download and inspect attestation content"
echo ""

echo "🎯 Example Validation Commands:"
echo "==============================="
echo ""
echo "# Verify signature with specific issuer"
echo "cosign verify --certificate-identity-regexp='.*@github.com' \\"
echo "  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \\"
echo "  $IMAGE_REF"
echo ""
echo "# Verify SLSA attestation with source verification"
echo "cosign verify-attestation --type slsaprovenance \\"
echo "  --certificate-identity-regexp='.*@github.com' \\"
echo "  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \\"
echo "  $IMAGE_REF"
echo ""
echo "# Extract and validate specific claims"
echo "cosign verify-attestation --type slsaprovenance $IMAGE_REF | \\"
echo "  jq -r '.payload' | base64 -d | \\"
echo "  jq '.predicate.invocation.configSource.uri'"
echo ""

echo "⚠️  Note: These commands will work once Sigstore TUF issues are resolved"
echo "   or when using private Sigstore instances."
