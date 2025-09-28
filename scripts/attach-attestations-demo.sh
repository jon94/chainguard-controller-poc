#!/bin/bash

# Demo: How to attach SLSA attestations to container registry
# This shows the process for production use (educational purposes)

set -e

echo "📋 SLSA Attestation Attachment Demo"
echo "==================================="
echo ""

echo "🎯 This script demonstrates how to attach SLSA attestations to container images"
echo "   in a production environment. Currently for educational purposes only."
echo ""

# Check if required tools are available
echo "🔧 Checking required tools..."

MISSING_TOOLS=()

if ! command -v cosign &> /dev/null; then
    MISSING_TOOLS+=("cosign")
fi

if ! command -v crane &> /dev/null; then
    MISSING_TOOLS+=("crane")
fi

if ! command -v jq &> /dev/null; then
    MISSING_TOOLS+=("jq")
fi

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo "❌ Missing required tools: ${MISSING_TOOLS[*]}"
    echo ""
    echo "📥 Installation commands:"
    for tool in "${MISSING_TOOLS[@]}"; do
        case $tool in
            "cosign")
                echo "   # Install Cosign"
                echo "   curl -O -L https://github.com/sigstore/cosign/releases/download/v2.2.4/cosign-linux-amd64"
                echo "   sudo mv cosign-linux-amd64 /usr/local/bin/cosign"
                echo "   sudo chmod +x /usr/local/bin/cosign"
                ;;
            "crane")
                echo "   # Install Crane"
                echo "   go install github.com/google/go-containerregistry/cmd/crane@latest"
                ;;
            "jq")
                echo "   # Install jq"
                echo "   sudo apt-get install jq  # or brew install jq"
                ;;
        esac
    done
    echo ""
    echo "⚠️  Install missing tools and run this script again."
    exit 1
fi

echo "✅ All required tools are available"
echo ""

# Demo configuration
IMAGE="jonlimpw/cg-demo"
ATTESTATION_FILE="slsa-provenance.json"

echo "🎯 Demo Configuration:"
echo "   Image: $IMAGE"
echo "   Attestation: $ATTESTATION_FILE"
echo ""

echo "📋 Step-by-Step Attestation Attachment Process:"
echo "=============================================="
echo ""

echo "Step 1: Generate SLSA Attestation (Done in CI)"
echo "----------------------------------------------"
echo "✅ This is already done in our GitHub Actions workflow"
echo "   • SLSA provenance generated during build"
echo "   • Attestation includes build metadata"
echo "   • Cryptographically signed attestation"
echo ""

echo "Step 2: Attach Attestation to Registry (Production)"
echo "--------------------------------------------------"
echo "Command that would be used in production:"
echo ""
echo "# Using Cosign to attach attestation"
echo "cosign attest --predicate \$ATTESTATION_FILE \\"
echo "  --type slsaprovenance \\"
echo "  \$IMAGE@\$DIGEST"
echo ""
echo "# Using OCI registry API directly"
echo "crane append -f \$ATTESTATION_FILE \\"
echo "  -t \$IMAGE:\$TAG-attestation \\"
echo "  \$IMAGE@\$DIGEST"
echo ""

echo "Step 3: Verify Attached Attestation"
echo "-----------------------------------"
echo "Commands for verification:"
echo ""
echo "# Verify with SLSA verifier"
echo "slsa-verifier verify-image \$IMAGE@\$DIGEST \\"
echo "  --source-uri github.com/jon94/chainguard-controller-poc"
echo ""
echo "# Verify with Cosign"
echo "cosign verify-attestation --type slsaprovenance \$IMAGE@\$DIGEST"
echo ""
echo "# Download and inspect attestation"
echo "cosign download attestation \$IMAGE@\$DIGEST | jq '.'"
echo ""

echo "📊 Current Status of Our Demo:"
echo "=============================="
echo ""

# Check if we have local attestation files
if [ -f "$ATTESTATION_FILE" ]; then
    echo "✅ Local attestation file exists: $ATTESTATION_FILE"
    
    # Validate the attestation structure
    if jq -e '.predicateType == "https://slsa.dev/provenance/v0.2"' "$ATTESTATION_FILE" >/dev/null 2>&1; then
        echo "✅ Valid SLSA v0.2 provenance format"
        
        # Show key information
        echo ""
        echo "📋 Attestation Details:"
        echo "   Predicate Type: $(jq -r '.predicateType' "$ATTESTATION_FILE")"
        echo "   Builder ID: $(jq -r '.predicate.builder.id' "$ATTESTATION_FILE")"
        echo "   Source URI: $(jq -r '.predicate.invocation.configSource.uri' "$ATTESTATION_FILE")"
        echo "   Build ID: $(jq -r '.predicate.metadata.buildInvocationId' "$ATTESTATION_FILE")"
    else
        echo "❌ Invalid attestation format"
    fi
else
    echo "⚠️  No local attestation file found"
    echo "   • Attestations are generated in CI logs"
    echo "   • Download CI artifacts to get attestation files"
    echo "   • Or check GitHub Actions workflow logs"
fi

echo ""
echo "🎯 Production Deployment Workflow:"
echo "================================="
echo ""
echo "1. 🏗️  Build: Generate container image"
echo "2. 📜 Attest: Create SLSA provenance"
echo "3. 🔐 Sign: Cryptographically sign attestation"
echo "4. 📤 Attach: Upload attestation to registry"
echo "5. 🚀 Deploy: Use attested image in production"
echo "6. ✅ Verify: Validate attestation before execution"
echo ""

echo "🔒 Enterprise Benefits:"
echo "======================"
echo ""
echo "✅ Supply Chain Transparency: Complete build provenance"
echo "✅ Non-Repudiation: Cryptographic proof of origin"
echo "✅ Compliance: SLSA Level 3 certification"
echo "✅ Automation: Integrated with CI/CD pipelines"
echo "✅ Verification: Multiple validation methods"
echo ""

echo "📚 Next Steps for Production:"
echo "============================"
echo ""
echo "1. Set up registry with attestation support (Harbor, ECR, etc.)"
echo "2. Configure CI/CD to attach attestations automatically"
echo "3. Implement admission controllers for verification"
echo "4. Set up monitoring and compliance dashboards"
echo "5. Train teams on attestation verification processes"
