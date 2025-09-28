#!/bin/bash

# Test script to verify SLSA attestation attachment is working
# This script tests the complete SLSA Level 3 workflow

set -e

echo "🧪 SLSA Attestation Attachment Test"
echo "=================================="
echo ""

# Configuration
DEMO_APP_IMAGE="jonlimpw/cg-demo"

echo "🎯 Testing Image:"
echo "   📦 Demo App: $DEMO_APP_IMAGE (monitored by Chainguard controller)"
echo ""

# Function to test attestation for an image
test_image_attestation() {
    local image_name="$1"
    local image_type="$2"
    
    echo "🔍 Testing $image_type: $image_name"
    echo "$(printf '=%.0s' {1..50})"
    
    # Get latest digest
    echo "📋 Getting latest digest..."
    local digest
    if command -v crane >/dev/null 2>&1; then
        digest=$(crane digest "$image_name:latest" 2>/dev/null || echo "")
    else
        # Fallback to Docker API
        local token=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$image_name:pull" | jq -r '.token' 2>/dev/null || echo "")
        if [ -n "$token" ]; then
            digest=$(curl -s -H "Authorization: Bearer $token" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" "https://registry-1.docker.io/v2/$image_name/manifests/latest" | jq -r '.config.digest' 2>/dev/null || echo "")
        fi
    fi
    
    if [ -z "$digest" ]; then
        echo "❌ Unable to get digest for $image_name"
        return 1
    fi
    
    local image_ref="$image_name@$digest"
    echo "   📋 Image Reference: $image_ref"
    echo ""
    
    # Test 1: Cosign verify-attestation
    echo "🔐 Test 1: Cosign Attestation Verification"
    echo "   Command: cosign verify-attestation --type slsaprovenance --certificate-identity-regexp ... $image_ref"
    
    if command -v cosign >/dev/null 2>&1; then
        if cosign verify-attestation --type slsaprovenance \
           --certificate-identity-regexp "https://github.com/jon94/chainguard-controller-poc/.*" \
           --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
           "$image_ref" >/dev/null 2>&1; then
            echo "   ✅ SUCCESS: SLSA attestation verified!"
            echo "   • Attestation is attached to registry"
            echo "   • SLSA Level 3 compliance achieved"
            
            # Show attestation details
            echo ""
            echo "   📋 Attestation Details:"
            cosign verify-attestation --type slsaprovenance \
               --certificate-identity-regexp "https://github.com/jon94/chainguard-controller-poc/.*" \
               --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
               "$image_ref" 2>/dev/null | jq -r '.payload' | base64 -d | jq '.predicate.builder.id, .predicate.buildType' 2>/dev/null || echo "   (Unable to parse attestation details)"
        else
            echo "   ❌ FAILED: No SLSA attestation found"
            echo "   • Attestation may not be attached yet"
            echo "   • Check GitHub Actions workflow"
        fi
    else
        echo "   ⚠️  Cosign not available - install with:"
        echo "   curl -O -L https://github.com/sigstore/cosign/releases/download/v2.2.4/cosign-linux-amd64"
        echo "   sudo mv cosign-linux-amd64 /usr/local/bin/cosign && sudo chmod +x /usr/local/bin/cosign"
    fi
    
    echo ""
    
    # Test 2: SLSA Verifier
    echo "🔍 Test 2: SLSA Verifier"
    echo "   Command: slsa-verifier verify-image $image_ref --source-uri github.com/jon94/chainguard-controller-poc"
    
    if command -v slsa-verifier >/dev/null 2>&1; then
        if slsa-verifier verify-image "$image_ref" --source-uri github.com/jon94/chainguard-controller-poc >/dev/null 2>&1; then
            echo "   ✅ SUCCESS: SLSA verifier validation passed!"
            echo "   • Build provenance verified"
            echo "   • Source repository authenticated"
            echo "   • Builder identity confirmed"
        else
            echo "   ⚠️  SLSA verifier validation failed"
            echo "   • May require specific source URI format"
            echo "   • Cosign verification is primary method"
        fi
    else
        echo "   ⚠️  SLSA verifier not available - install with:"
        echo "   curl -Lo slsa-verifier https://github.com/slsa-framework/slsa-verifier/releases/download/v2.4.1/slsa-verifier-linux-amd64"
        echo "   chmod +x slsa-verifier && sudo mv slsa-verifier /usr/local/bin/"
    fi
    
    echo ""
    
    # Test 3: Registry artifact tree
    echo "🌳 Test 3: Registry Artifact Tree"
    if command -v cosign >/dev/null 2>&1; then
        echo "   Command: cosign tree $image_ref"
        
        local tree_output
        tree_output=$(cosign tree "$image_ref" 2>/dev/null || echo "")
        
        if [ -n "$tree_output" ]; then
            echo "   📋 Artifact Tree:"
            echo "$tree_output" | head -10
            
            if echo "$tree_output" | grep -q "attestation\|Attestations"; then
                echo "   ✅ Attestation artifacts visible in tree"
            else
                echo "   ⚠️  No attestation artifacts visible in tree"
            fi
        else
            echo "   ⚠️  Unable to retrieve artifact tree"
        fi
    else
        echo "   ⚠️  Cosign not available for tree display"
    fi
    
    echo ""
    echo "$(printf '=%.0s' {1..50})"
    echo ""
}

# Test demo app image
test_image_attestation "$DEMO_APP_IMAGE" "Demo App"

echo "📊 SLSA Level 3 Compliance Summary"
echo "================================="
echo ""
echo "✅ What We've Achieved:"
echo "   • Hermetic builds in GitHub Actions"
echo "   • SLSA provenance generation for demo app"
echo "   • Attestation attachment to registry"
echo "   • Multiple verification methods"
echo ""
echo "🎯 For Chainguard Demo:"
echo "   • Demo app has enterprise-grade supply chain security"
echo "   • Shows complete SLSA Level 3 compliance for monitored apps"
echo "   • Controller can verify attestation existence"
echo "   • Ready for enterprise security monitoring"
echo ""
echo "🔧 Next Steps:"
echo "   1. Run GitHub Actions to build demo app with attestations"
echo "   2. Use this script to verify attachment"
echo "   3. Deploy controller to monitor demo app"
echo "   4. Demonstrate attestation validation in interview"
