# Chainguard Controller MVP - Command Reference

This document contains all the commands used to build and deploy the Chainguard Image Policy Controller MVP, organized by purpose with brief descriptions.

## 🛠️ Development Environment Setup

### Install Prerequisites
```bash
# Install Go programming language
brew install go

# Download and install Kubebuilder CLI
curl -L -o kubebuilder "https://go.kubebuilder.io/dl/latest/$(go env GOOS)/$(go env GOARCH)"
chmod +x kubebuilder
```

### Verify Installation
```bash
# Check Go version
go version

# Verify kubectl access to GKE cluster
kubectl cluster-info
kubectl get nodes
```

## 🏗️ Project Initialization

### Initialize Kubebuilder Project
```bash
# Create controller subdirectory and initialize project
mkdir controller && cd controller
../kubebuilder init --domain chainguard.dev --repo github.com/jonlimpw/chainguard-controller
```

### Create Custom Resource and Controller
```bash
# Generate ImagePolicy CRD and controller scaffolding
../kubebuilder create api --group security --version v1 --kind ImagePolicy --resource --controller
```

## 🔨 Build and Test Commands

### Generate Manifests and Code
```bash
# Generate CRD manifests from Go types
make manifests

# Generate deepcopy methods and other boilerplate
make generate

# Generate both manifests and code
make manifests generate
```

### Build and Test
```bash
# Run unit tests with coverage
make test

# Format Go code
go fmt ./...

# Run Go vet for static analysis
go vet ./...

# Build controller binary
make build

# Build Docker image
make docker-build IMG=chainguard-controller:latest
```

## 🚀 Deployment Commands

### Install CRDs
```bash
# Install Custom Resource Definitions to cluster
make install
```

### Deploy Controller
```bash
# Deploy controller to cluster with specific image
make deploy IMG=gcr.io/$(gcloud config get-value project)/chainguard-controller:latest

# Wait for controller to be ready
kubectl wait --for=condition=available --timeout=300s deployment/chainguard-controller-controller-manager -n chainguard-controller-system
```

### Uninstall (Cleanup)
```bash
# Remove controller deployment
make undeploy

# Remove CRDs
make uninstall
```

## 🐳 Docker Commands

### Build Demo Application
```bash
# Build demo app Docker image (manual or via GitHub Actions)
cd demo-app
docker build -t jonlimpw/cg-demo:v1.0.0 -t jonlimpw/cg-demo:latest .

# Push to DockerHub
docker push jonlimpw/cg-demo:v1.0.0
docker push jonlimpw/cg-demo:latest

# Get image digest for compliance testing
docker inspect --format='{{index .RepoDigests 0}}' jonlimpw/cg-demo:latest
```

### Controller Image Management
```bash
# Tag controller image for GCR
docker tag chainguard-controller:latest gcr.io/$(gcloud config get-value project)/chainguard-controller:latest

# Push controller image to GCR
docker push gcr.io/$(gcloud config get-value project)/chainguard-controller:latest
```

## 📋 Demo and Testing Commands

### Deploy Demo Resources
```bash
# Create demo namespace with monitoring label
kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace demo monitored=true --overwrite
kubectl label namespace default monitored=true --overwrite

# Apply ImagePolicy for monitoring
kubectl apply -f controller/config/samples/demo-imagepolicy.yaml

# Deploy sample applications (compliant and non-compliant)
kubectl apply -f controller/config/samples/demo-deployment.yaml
```

### Monitor Compliance Status
```bash
# View ImagePolicy resources
kubectl get imagepolicy
kubectl get imagepolicy -o wide

# Get detailed policy status
kubectl get imagepolicy jonlimpw-demo-policy -o yaml | grep -A 20 "status:"

# Check compliance metrics (updates every 10 seconds in demo)
kubectl get imagepolicy jonlimpw-demo-policy -o jsonpath='{.status.complianceStatus}'
kubectl get imagepolicy jonlimpw-demo-policy -o jsonpath='{.status.compliantDeployments}/{.status.totalDeployments}'

# View detailed deployment compliance
kubectl get imagepolicy jonlimpw-demo-policy -o jsonpath='{.status.monitoredDeployments}' | jq '.'
```

### View Events and Logs
```bash
# Check compliance events
kubectl get events --field-selector involvedObject.kind=ImagePolicy

# View controller logs
kubectl logs -n chainguard-controller-system deployment/chainguard-controller-controller-manager -c manager -f

# Get recent controller activity
kubectl logs -n chainguard-controller-system deployment/chainguard-controller-controller-manager -c manager --tail=20
```

### Check Deployments
```bash
# List monitored deployments
kubectl get deployments -A -l app=demo-app

# Describe specific deployment
kubectl describe deployment demo-app

# Check pod status
kubectl get pods -l app=demo-app
```

## 🧹 Cleanup Commands

### Remove Demo Resources
```bash
# Delete sample deployments and policies
kubectl delete -f controller/config/samples/

# Remove demo namespace
kubectl delete namespace demo

# Remove labels from default namespace
kubectl label namespace default monitored-
```

### Complete Cleanup
```bash
# Remove controller and CRDs
make undeploy
make uninstall

# Clean up Docker images
docker rmi chainguard-controller:latest
docker rmi jonlimpw/demo-app:latest jonlimpw/demo-app:v1.0.0
```

## 🔧 Utility Commands

### File Permissions
```bash
# Make scripts executable
chmod +x /Users/jonathan.lim/chainguard-controller-poc/demo-app/server.sh
chmod +x /Users/jonathan.lim/chainguard-controller-poc/scripts/*.sh
```

### Project Structure
```bash
# View project structure
tree /Users/jonathan.lim/chainguard-controller-poc

# List directory contents
ls -la /Users/jonathan.lim/chainguard-controller-poc
```

### Git Operations (if using version control)
```bash
# Initialize git repository
git init

# Add all files
git add .

# Initial commit
git commit -m "Initial Chainguard Controller MVP implementation"

# Add remote and push (if desired)
git remote add origin <your-repo-url>
git push -u origin main
```

## 🎯 Automated Script Commands

### All-in-One Demo Setup
```bash
# Deploy controller to GKE cluster
./scripts/deploy-controller.sh

# Build and push demo application (manual or GitHub Actions)
cd demo-app
docker build -t jonlimpw/cg-demo:v1.0.0 -t jonlimpw/cg-demo:latest .
docker push jonlimpw/cg-demo:v1.0.0
docker push jonlimpw/cg-demo:latest

# Run interactive demo flow
./scripts/demo-flow.sh
```

### Individual Script Usage
```bash
# Build specific version of demo app
cd demo-app
docker build -t jonlimpw/cg-demo:v2.0.0 -t jonlimpw/cg-demo:latest .
docker push jonlimpw/cg-demo:v2.0.0
docker push jonlimpw/cg-demo:latest

# Deploy controller with custom settings
./scripts/deploy-controller.sh

# Run demo with specific parameters
./scripts/demo-flow.sh
```

## 🔍 Debugging Commands

### Controller Debugging
```bash
# Run controller locally (against remote cluster)
make run

# Check controller manager status
kubectl get pods -n chainguard-controller-system

# Describe controller deployment
kubectl describe deployment chainguard-controller-controller-manager -n chainguard-controller-system

# Check RBAC permissions
kubectl auth can-i get deployments --as=system:serviceaccount:chainguard-controller-system:chainguard-controller-controller-manager
```

### CRD Debugging
```bash
# Validate CRD installation
kubectl get crd imagepolicies.security.chainguard.dev

# Check CRD schema
kubectl explain imagepolicy.spec

# Validate resource creation
kubectl apply --dry-run=client -f controller/config/samples/demo-imagepolicy.yaml
```

### Network and API Debugging
```bash
# Test DockerHub API access from cluster
kubectl run debug-pod --image=curlimages/curl --rm -it -- curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:jonlimpw/demo-app:pull"

# Check cluster DNS resolution
kubectl run debug-pod --image=busybox --rm -it -- nslookup registry-1.docker.io
```

## 📊 Monitoring Commands

### Resource Usage
```bash
# Check controller resource usage
kubectl top pods -n chainguard-controller-system

# Monitor resource creation
kubectl get imagepolicy --watch

# Monitor events in real-time
kubectl get events --watch
```

### Performance Testing
```bash
# Create multiple policies for scale testing
for i in {1..10}; do
  kubectl apply -f - <<EOF
apiVersion: security.chainguard.dev/v1
kind: ImagePolicy
metadata:
  name: test-policy-$i
  namespace: default
spec:
  repository: "jonlimpw/demo-app"
  checkIntervalSeconds: 300
EOF
done
```

---

## 📝 Notes

- **GKE Context**: All `kubectl` commands assume you're connected to your GKE cluster
- **DockerHub Account**: Commands assume access to `jonlimpw` DockerHub repository
- **Permissions**: Some commands may require cluster-admin permissions
- **Timeouts**: Deployment commands include reasonable timeouts for demo purposes
- **Cleanup**: Always run cleanup commands after demos to avoid resource conflicts

## 🎯 Quick Reference

### Most Important Commands for Demo
```bash
# 1. Deploy everything
./scripts/deploy-controller.sh

# Build demo app (manual or GitHub Actions)
cd demo-app && docker build -t jonlimpw/cg-demo:latest . && docker push jonlimpw/cg-demo:latest

# 2. Run demo
./scripts/demo-flow.sh

# 3. Monitor status
kubectl get imagepolicy -o wide
kubectl logs -n chainguard-controller-system deployment/chainguard-controller-controller-manager -c manager --tail=10

# 4. Cleanup
kubectl delete -f controller/config/samples/
make undeploy
```

This command reference provides everything needed to build, deploy, demo, and maintain the Chainguard Image Policy Controller MVP.
