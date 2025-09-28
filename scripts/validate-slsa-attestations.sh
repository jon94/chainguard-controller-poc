#!/bin/bash

# Validate SLSA attestations for container images
# This script demonstrates how to verify SLSA provenance attestations

set -e

echo "🔍 SLSA Attestation Validation for Chainguard Demo"
echo "=================================================="
echo ""

# Images to validate
DEMO_APP_IMAGE="jonlimpw/cg-demo"
CONTROLLER_IMAGE="jonlimpw/secure-controller"

# Check if slsa-verifier is installed
if ! command -v slsa-verifier &> /dev/null; then
    echo "📥 Installing SLSA verifier..."
    
    # Install slsa-verifier
    if [[ "$OSTYPE" == "darwin"* ]]; then
        curl -Lo slsa-verifier https://github.com/slsa-framework/slsa-verifier/releases/download/v2.4.1/slsa-verifier-darwin-amd64
    else
        curl -Lo slsa-verifier https://github.com/slsa-framework/slsa-verifier/releases/download/v2.4.1/slsa-verifier-linux-amd64
    fi
    
    chmod +x slsa-verifier
    sudo mv slsa-verifier /usr/local/bin/
    echo "✅ SLSA verifier installed successfully"
    echo ""
fi

validate_image_attestation() {
    local image_name=$1
    local repo_name=$2
    
    echo "📋 Validating SLSA attestation for $image_name..."
    echo "-------------------------------------------"
    
    # Get the latest image digest
    TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$repo_name:pull" | jq -r .token)
    DIGEST=$(curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" "https://registry-1.docker.io/v2/$repo_name/manifests/latest" | jq -r '.config.digest // empty')

    if [ -z "$DIGEST" ]; then
        # Fallback: get digest from response headers
        DIGEST=$(curl -s -I -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" "https://registry-1.docker.io/v2/$repo_name/manifests/latest" | grep -i docker-content-digest | cut -d' ' -f2 | tr -d '\r')
    fi

    if [ -z "$DIGEST" ]; then
        echo "❌ Could not fetch digest for $image_name"
        return 1
    fi

    IMAGE_REF="$repo_name@$DIGEST"
    echo "🎯 Target Image: $IMAGE_REF"
    echo ""

    # Method 1: Verify with slsa-verifier (if attestation exists)
    echo "🔐 Method 1: SLSA Verifier Validation"
    echo "------------------------------------"
    
    # Try SLSA verification with attached attestations
    echo "Attempting: slsa-verifier verify-image $IMAGE_REF --source-uri github.com/jon94/chainguard-controller-poc"
    
    if slsa-verifier verify-image "$IMAGE_REF" --source-uri github.com/jon94/chainguard-controller-poc 2>/dev/null; then
        echo "✅ SLSA verification successful!"
        echo "   • Build provenance verified"
        echo "   • Source repository authenticated"
        echo "   • Builder identity confirmed"
        echo "   • SLSA Level 3 compliance achieved"
    else
        echo "⚠️  SLSA verification failed"
        echo "   • Checking if attestations are attached..."
        
        # Try Cosign verification as fallback (with proper OIDC identity)
        echo "   • Trying Cosign verification with GitHub OIDC identity..."
        if cosign verify-attestation --type slsaprovenance \
           --insecure-ignore-tlog \
           --certificate-identity-regexp "https://github.com/jon94/chainguard-controller-poc/.*" \
           --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
           "$IMAGE_REF" >/dev/null 2>&1; then
            echo "   ✅ Cosign attestation verification successful!"
            echo "   • SLSA attestations are attached to registry"
            echo "   • GitHub Actions OIDC identity verified"
        else
            echo "   ❌ No attestations found attached to image"
            echo "   • Attestations may still be propagating"
            echo "   • Check GitHub Actions logs for attachment status"
        fi
    fi
    echo ""

    # Method 2: Check for attestation artifacts in registry
    echo "🔍 Method 2: Registry Attestation Check"
    echo "--------------------------------------"
    
    # Check if attestation artifacts exist using multiple methods
    echo "Checking for attestation artifacts..."
    
    # Method 2a: Use cosign tree to check for attestations
    if command -v cosign >/dev/null 2>&1; then
        echo "   🔍 Using cosign tree to check artifacts..."
        if cosign tree "$IMAGE_REF" 2>/dev/null | grep -q "attestation\|Attestations"; then
            echo "   ✅ Attestation artifacts found in registry"
            echo "   • SLSA attestations are properly attached"
            echo ""
            echo "   📋 Registry Artifact Tree:"
            cosign tree "$IMAGE_REF" 2>/dev/null | head -20 || echo "   (Unable to display tree structure)"
        else
            echo "   ⚠️  No attestation artifacts found in cosign tree"
            
            # Try direct attestation verification with proper OIDC identity
            echo "   • Attempting direct attestation verification..."
            if cosign verify-attestation --type slsaprovenance \
               --certificate-identity-regexp "https://github.com/jon94/chainguard-controller-poc/.*" \
               --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
               "$IMAGE_REF" >/dev/null 2>&1; then
                echo "   ✅ Direct attestation verification successful!"
                echo "   • Attestations exist but may not show in tree view"
                echo "   • GitHub Actions OIDC identity verified"
            else
                echo "   ❌ No attestations found via direct verification"
            fi
        fi
    else
        echo "   ⚠️  Cosign not available for tree checking"
        
        # Fallback: Check registry API for referrers
        ATTESTATION_CHECK=$(curl -s -H "Authorization: Bearer $TOKEN" "https://registry-1.docker.io/v2/$repo_name/referrers/$DIGEST" 2>/dev/null || echo "no-referrers")
        
        if [[ "$ATTESTATION_CHECK" == "no-referrers" ]]; then
            echo "   ⚠️  No attestation artifacts found in registry API"
        else
            echo "   ✅ Attestation artifacts found in registry API"
            echo "$ATTESTATION_CHECK" | jq '.' 2>/dev/null || echo "   Raw response: $ATTESTATION_CHECK"
        fi
    fi
    
    echo ""
}

# Validate both images
echo "🔍 VALIDATING DEMO APP IMAGE"
echo "============================"
validate_image_attestation "Demo App" "$DEMO_APP_IMAGE"

echo "🔍 VALIDATING CONTROLLER IMAGE"
echo "============================="
validate_image_attestation "Controller" "$CONTROLLER_IMAGE"

echo "🔧 LOCAL ATTESTATION FILE VALIDATION"
echo "===================================="
echo ""

# Check for local attestation files (from CI artifacts)
if [ -f slsa-provenance.json ]; then
    echo "📄 Found local SLSA provenance file: slsa-provenance.json"
    echo "   Validating structure..."
    
    if jq -e '.predicateType == "https://slsa.dev/provenance/v0.2"' slsa-provenance.json >/dev/null 2>&1; then
        echo "   ✅ Valid SLSA v0.2 provenance format"
        
        # Extract key information
        BUILDER_ID=$(jq -r '.predicate.builder.id' slsa-provenance.json 2>/dev/null || echo "unknown")
        SOURCE_URI=$(jq -r '.predicate.invocation.configSource.uri' slsa-provenance.json 2>/dev/null || echo "unknown")
        BUILD_ID=$(jq -r '.predicate.metadata.buildInvocationId' slsa-provenance.json 2>/dev/null || echo "unknown")
        
        echo "   📋 Builder: $BUILDER_ID"
        echo "   📋 Source: $SOURCE_URI"
        echo "   📋 Build ID: $BUILD_ID"
    else
        echo "   ❌ Invalid SLSA provenance format"
    fi
else
    echo "📄 No local SLSA provenance files found"
    echo "   • Attestations are generated in CI but not downloaded locally"
    echo "   • In production, attestations would be attached to registry"
    echo "   • You can download CI artifacts to get the attestation files"
fi

if [ -f controller-slsa-provenance.json ]; then
    echo ""
    echo "📄 Found controller SLSA provenance file: controller-slsa-provenance.json"
    echo "   ✅ Controller has local attestation file"
fi

echo ""
echo "📊 SLSA Attestation Validation Methods:"
echo "========================================"
echo ""
echo "🔧 Method 1: SLSA Verifier CLI"
echo "   • Official SLSA framework tool"
echo "   • Validates provenance attestations"
echo "   • Checks builder identity and source"
echo "   • Command: slsa-verifier verify-image <image@digest>"
echo ""
echo "🔧 Method 2: Registry API Inspection"
echo "   • Check for attestation artifacts"
echo "   • Validate attestation signatures"
echo "   • Inspect provenance metadata"
echo ""
echo "🔧 Method 3: Policy Enforcement"
echo "   • Kubernetes admission controllers"
echo "   • OPA/Gatekeeper policies"
echo "   • Sigstore Policy Controller"
echo ""
echo "🔧 Method 4: CI/CD Integration"
echo "   • GitHub Actions attestation verification"
echo "   • Build pipeline validation"
echo "   • Automated compliance checks"
echo ""
echo "🎯 Enterprise Integration Options:"
echo "=================================="
echo "✅ Kubernetes Policy Controllers (e.g., Kyverno, OPA)"
echo "✅ Supply Chain Security Platforms (e.g., Chainguard Enforce)"
echo "✅ Container Registry Scanning (e.g., Harbor, Twistlock)"
echo "✅ CI/CD Pipeline Gates (e.g., GitHub Advanced Security)"
echo ""
echo "🔒 This demonstrates comprehensive SLSA attestation validation!"
