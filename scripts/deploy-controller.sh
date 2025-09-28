#!/bin/bash

# Deploy the Chainguard Image Policy Controller to GKE

set -e

echo "🚀 Deploying Chainguard Image Policy Controller to GKE..."

# Build and load the controller image
cd "$(dirname "$0")/../controller"

echo "🔨 Building controller image..."
make docker-build IMG=chainguard-controller:latest

echo "📤 Loading image to GKE cluster..."
# For GKE, we need to push to a registry accessible by the cluster
# You can modify this to push to GCR or another registry
docker tag chainguard-controller:latest gcr.io/$(gcloud config get-value project)/chainguard-controller:latest
docker push gcr.io/$(gcloud config get-value project)/chainguard-controller:latest

echo "📋 Installing CRDs..."
make install

echo "🎛️  Deploying controller..."
make deploy IMG=gcr.io/$(gcloud config get-value project)/chainguard-controller:latest

echo "⏳ Waiting for controller to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/chainguard-controller-controller-manager -n chainguard-controller-system

echo "✅ Controller deployed successfully!"
echo ""
echo "🔍 Check controller status:"
echo "   kubectl get pods -n chainguard-controller-system"
echo ""
echo "📊 View controller logs:"
echo "   kubectl logs -n chainguard-controller-system deployment/chainguard-controller-controller-manager -c manager"
