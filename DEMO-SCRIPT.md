# Chainguard Interview Demo Script

## 🎯 Demo Objective
Demonstrate a working Kubernetes controller that monitors container image compliance, showcasing:
- Deep Kubernetes expertise
- Supply chain security understanding
- Enterprise-grade architecture thinking
- Real-world problem-solving skills

## ⏱️ Timeline (15-20 minutes)

### Pre-Demo Setup (5 minutes)
1. **Environment Check**
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

2. **Controller Deployment**
   ```bash
   ./scripts/deploy-controller.sh
   ```

3. **Demo App Preparation**
   ```bash
   # Build and push demo app (or use GitHub Actions)
   cd demo-app
   docker build -t jonlimpw/demo-app:v1.0.0 -t jonlimpw/demo-app:latest .
   docker push jonlimpw/demo-app:v1.0.0
   docker push jonlimpw/demo-app:latest
   ```

### Live Demo (10-15 minutes)

#### Act 1: The Problem (2 minutes)
**Narrative**: "In enterprise environments, ensuring containers use the latest, secure images is critical. Teams often deploy using tags like 'latest' or specific versions, but these don't guarantee you're running the most recent, patched version."

**Show the challenge**:
```bash
# Show typical deployment pattern
cat controller/config/samples/demo-deployment.yaml
```

**Key Points**:
- Tags are mutable - `latest` can point to different images
- No visibility into image freshness
- Manual process to track updates
- Compliance gaps in large organizations

#### Act 2: The Solution (3 minutes)
**Narrative**: "Our ImagePolicy controller solves this by continuously monitoring DockerHub for the latest image digests and tracking deployment compliance in real-time."

**Deploy the policy**:
```bash
kubectl apply -f controller/config/samples/demo-imagepolicy.yaml
kubectl get imagepolicy -o wide
```

**Explain the architecture**:
- Custom Resource Definition for policy specification
- Controller queries DockerHub Registry API
- Tracks compliance across namespaces and deployments
- Kubernetes-native with proper RBAC

#### Act 3: Detection in Action (5 minutes)
**Deploy non-compliant workloads**:
```bash
kubectl apply -f controller/config/samples/demo-deployment.yaml
kubectl get deployments -A -l app=demo-app
```

**Show real-time monitoring**:
```bash
# Watch the controller detect and analyze
kubectl get imagepolicy jonlimpw-demo-policy -o yaml | grep -A 20 "status:"

# Show compliance metrics
kubectl get imagepolicy jonlimpw-demo-policy -o jsonpath='{.status.complianceStatus}'
echo ""
kubectl get imagepolicy jonlimpw-demo-policy -o jsonpath='{.status.compliantDeployments}/{.status.totalDeployments}'
echo " deployments compliant"
```

**Demonstrate events and audit trail**:
```bash
kubectl get events --field-selector involvedObject.kind=ImagePolicy
```

#### Act 4: Enterprise Features (3 minutes)
**Show detailed compliance tracking**:
```bash
# Detailed deployment analysis
kubectl get imagepolicy jonlimpw-demo-policy -o jsonpath='{.status.monitoredDeployments}' | jq '.'

# Controller observability
kubectl logs -n chainguard-controller-system \
  deployment/chainguard-controller-controller-manager \
  -c manager --tail=10
```

**Discuss scalability and enterprise features**:
- Namespace and label selectors for targeted monitoring
- Configurable check intervals
- Event-driven architecture
- Extensible for signing and attestation

#### Act 5: Future Vision (2 minutes)
**Narrative**: "This foundation enables advanced supply chain security features that align with Chainguard's mission."

**Show extension points**:
```yaml
# Future: Image signing verification
spec:
  repository: "jonlimpw/demo-app"
  signingPolicy:
    required: true
    keyRef: "cosign-public-key"

# Future: SLSA attestation checking
spec:
  attestationPolicy:
    slsaLevel: 3
    requiredPredicates:
      - "https://slsa.dev/provenance/v0.2"
```

**Connect to Chainguard value**:
- Zero-trust container security
- Policy-as-code approach
- Developer-friendly compliance
- Enterprise-scale observability

## 🎤 Key Talking Points

### Technical Depth
- "Built using Kubebuilder for production-grade controller patterns"
- "Leverages DockerHub Registry API v2 for digest resolution"
- "Implements proper Kubernetes reconciliation loops with exponential backoff"
- "Uses structured logging and event recording for observability"

### Enterprise Thinking
- "Designed for multi-tenant environments with namespace isolation"
- "Configurable policies allow gradual rollout and exceptions"
- "Event-driven architecture scales to thousands of deployments"
- "Extensible plugin system for custom compliance rules"

### Supply Chain Security
- "Immutable image references prevent supply chain attacks"
- "Continuous monitoring detects drift from approved images"
- "Audit trail provides compliance evidence for SOC2/FedRAMP"
- "Foundation for zero-trust container deployment policies"

### Chainguard Alignment
- "Demonstrates understanding of container security challenges"
- "Shows ability to build developer-friendly security tools"
- "Exhibits enterprise sales engineering mindset"
- "Provides concrete foundation for customer conversations"

## 🔧 Troubleshooting

### Common Issues
1. **Controller not starting**: Check RBAC permissions
2. **DockerHub API errors**: Verify network connectivity
3. **No deployments found**: Check namespace/label selectors
4. **Slow digest resolution**: DockerHub rate limiting

### Backup Demos
If live demo fails:
1. Show pre-recorded terminal session
2. Walk through code architecture
3. Discuss design decisions and trade-offs
4. Focus on enterprise requirements gathering

## 🎯 Success Metrics

### Technical Demonstration
- ✅ Working controller deployment
- ✅ Real-time compliance monitoring
- ✅ DockerHub API integration
- ✅ Kubernetes-native implementation

### Business Value Communication
- ✅ Enterprise security challenges identified
- ✅ Developer workflow integration shown
- ✅ Scalability and extensibility discussed
- ✅ Chainguard value proposition connected

### Interview Performance
- ✅ Confident technical presentation
- ✅ Clear problem/solution articulation
- ✅ Enterprise mindset demonstrated
- ✅ Questions handled professionally

## 📝 Q&A Preparation

### Expected Questions

**Q: How does this scale to thousands of deployments?**
A: The controller uses efficient list/watch patterns with label selectors. We can implement sharding across multiple controller instances and use caching to minimize API calls.

**Q: What about private registries or air-gapped environments?**
A: The architecture supports pluggable registry providers. For air-gapped, we'd implement a local registry scanner with the same compliance interface.

**Q: How do you handle registry authentication?**
A: Currently uses public DockerHub API. For private repos, we'd integrate with Kubernetes secrets and support various auth methods (basic, token, service accounts).

**Q: What's the performance impact on the cluster?**
A: Minimal - the controller only queries external APIs on configurable intervals. The reconciliation loop is efficient with proper caching and exponential backoff.

**Q: How does this integrate with CI/CD pipelines?**
A: Teams can update ImagePolicy resources as part of their deployment process. The controller provides status that CI/CD can query for compliance gates.

---

*Remember: This demo showcases not just technical skills, but enterprise thinking and customer empathy - key qualities for a Chainguard Sales Engineer.*
