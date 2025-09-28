# Chainguard Image Policy Controller

A Kubernetes controller that monitors container image compliance by ensuring deployments use the latest signed image digests from DockerHub. Built for demonstrating enterprise-grade supply chain security practices.

## 🎯 Overview

This MVP demonstrates a custom Kubernetes controller that:

- **Monitors DockerHub repositories** for latest image digests
- **Tracks deployment compliance** across namespaces
- **Flags non-compliant deployments** using outdated or tag-based images
- **Provides real-time status updates** via Kubernetes API
- **Creates audit events** for compliance violations
- **Extensible architecture** for future attestation and signing verification

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   ImagePolicy   │    │   Controller     │    │   DockerHub     │
│   (CRD)         │◄──►│   Reconciler     │◄──►│   Registry API  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       ▼                       │
         │              ┌──────────────────┐             │
         └─────────────►│   Deployments    │             │
                        │   Monitoring     │◄────────────┘
                        └──────────────────┘
```

### Components

1. **ImagePolicy CRD**: Defines monitoring rules and compliance requirements
2. **Controller**: Reconciles policies, queries DockerHub, and updates status
3. **DockerHub Integration**: Fetches latest image digests via Registry API v2
4. **Compliance Engine**: Analyzes deployments and tracks violations

## 🚀 Quick Start

### Prerequisites

- GKE cluster with kubectl access
- Docker CLI with DockerHub account (`jonlimpw`)
- Go 1.21+ (installed automatically)
- Kubebuilder (installed automatically)

### 1. Deploy the Controller

```bash
# Clone and deploy
git clone <this-repo>
cd chainguard-controller-poc

# Deploy to your GKE cluster
./scripts/deploy-controller.sh
```

### 2. Build and Push Demo Application

```bash
# Build demo app manually (or use GitHub Actions for CI/CD)
cd demo-app
docker build -t jonlimpw/demo-app:v1.0.0 -t jonlimpw/demo-app:latest .
docker push jonlimpw/demo-app:v1.0.0
docker push jonlimpw/demo-app:latest
```

### 3. Run the Demo

```bash
# Interactive demo flow
./scripts/demo-flow.sh
```

## 📋 Demo Flow

The demo showcases a complete compliance monitoring scenario:

### Step 1: Policy Creation
```yaml
apiVersion: security.chainguard.dev/v1
kind: ImagePolicy
metadata:
  name: jonlimpw-demo-policy
spec:
  repository: "jonlimpw/demo-app"
  checkIntervalSeconds: 10
  enforceLatestDigest: true
```

### Step 2: Non-Compliant Deployment
```yaml
spec:
  containers:
  - name: demo-app
    image: jonlimpw/demo-app:latest  # ❌ Tag-based (non-compliant)
```

### Step 3: Compliance Detection
```bash
$ kubectl get imagepolicy
NAME                   REPOSITORY         COMPLIANCE     TOTAL   COMPLIANT
jonlimpw-demo-policy   jonlimpw/demo-app  NonCompliant   2       0
```

### Step 4: Remediation
```yaml
spec:
  containers:
  - name: demo-app
    image: jonlimpw/demo-app@sha256:abc123...  # ✅ Digest-based (compliant)
```

## 🔧 Configuration

### ImagePolicy Specification

| Field | Description | Default |
|-------|-------------|---------|
| `repository` | DockerHub repository to monitor | Required |
| `checkIntervalSeconds` | How often to check for updates | 60 |
| `enforceLatestDigest` | Flag non-latest digests | true |
| `namespaceSelector` | Which namespaces to monitor | All |
| `deploymentSelector` | Which deployments to monitor | All |

### Example Configurations

#### Monitor Specific Namespace
```yaml
spec:
  repository: "jonlimpw/demo-app"
  namespaceSelector:
    matchLabels:
      environment: "production"
```

#### Monitor Specific Applications
```yaml
spec:
  repository: "jonlimpw/demo-app"
  deploymentSelector:
    matchLabels:
      app: "critical-service"
```

## 📊 Monitoring & Observability

### Status Information
```bash
# View policy status
kubectl get imagepolicy -o wide

# Detailed compliance information
kubectl describe imagepolicy jonlimpw-demo-policy

# View compliance events
kubectl get events --field-selector involvedObject.kind=ImagePolicy
```

### Controller Logs
```bash
# View controller activity
kubectl logs -n chainguard-controller-system \
  deployment/chainguard-controller-controller-manager \
  -c manager -f
```

### Metrics (Future Enhancement)
- Compliance rate per repository
- Time to detect new images
- Policy violation counts
- MTTR for compliance issues

## 🔮 Future Extensions

This MVP provides a foundation for advanced supply chain security features:

### Phase 2: Image Signing Verification
```yaml
spec:
  repository: "jonlimpw/demo-app"
  signingPolicy:
    required: true
    keyRef: "cosign-public-key"
    issuer: "https://accounts.google.com"
```

### Phase 3: Attestation Verification
```yaml
spec:
  repository: "jonlimpw/demo-app"
  attestationPolicy:
    slsaLevel: 3
    requiredPredicates:
      - "https://slsa.dev/provenance/v0.2"
      - "https://in-toto.io/Statement/v0.1"
```

### Phase 4: Admission Control
```yaml
spec:
  repository: "jonlimpw/demo-app"
  enforcement:
    mode: "block"  # Prevent non-compliant deployments
    exceptions:
      - namespace: "development"
```

## 🏢 Enterprise Value Proposition

### For Security Teams
- **Continuous Compliance**: Automated monitoring of image freshness
- **Audit Trail**: Complete event history for compliance reporting
- **Policy as Code**: Version-controlled security policies
- **Zero-Trust**: Verify every image before deployment

### For DevOps Teams
- **Developer Friendly**: Clear feedback on compliance status
- **CI/CD Integration**: Automated policy updates on image builds
- **Operational Visibility**: Real-time compliance dashboards
- **Gradual Rollout**: Namespace and label-based targeting

### For Platform Teams
- **Kubernetes Native**: Leverages existing RBAC and tooling
- **Extensible**: Plugin architecture for custom policies
- **Scalable**: Efficient reconciliation for large clusters
- **Observable**: Rich metrics and logging integration

## 🛠️ Development

### Local Development
```bash
# Run tests
cd controller
make test

# Run locally (against remote cluster)
make run

# Build and test
make docker-build IMG=chainguard-controller:dev
```

### Project Structure
```
chainguard-controller-poc/
├── controller/                 # Kubebuilder project
│   ├── api/v1/                # CRD definitions
│   ├── internal/controller/   # Controller logic
│   ├── config/               # Kubernetes manifests
│   └── cmd/                  # Main application
├── demo-app/                 # Sample application
├── scripts/                  # Demo and deployment scripts
└── README.md                # This file
```

## 🤝 Contributing

This is a demo project for interview purposes, but the architecture supports:

- Additional registry providers (GCR, ECR, Harbor)
- Custom compliance policies
- Integration with policy engines (OPA, Falco)
- Advanced attestation formats (SLSA, in-toto)

## 📄 License

Apache License 2.0 - See LICENSE file for details.

---

**Built for Chainguard Enterprise Sales Engineer Interview**  
*Demonstrating Kubernetes expertise and supply chain security understanding*
