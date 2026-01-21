# Kyverno Policy Management

This directory contains **Kyverno policies** for the GitOps platform, providing policy-as-code for Kubernetes admission control, validation, mutation, and generation.

## 📋 Policy Categories

### 1. **Cluster Policies** (`cluster-policies/`)
Platform-wide policies applied to all namespaces:
- **Security:** Image security, pod security, privilege escalation
- **Resource governance:** CPU/memory limits, quotas
- **Naming standards:** Label requirements, naming patterns
- **Best practices:** Health probes, readiness checks

### 2. **Namespace Policies** (`namespace-policies/`)
Environment-specific policies:
- **Production:** Strict security, required analysis templates, mTLS enforcement
- **Staging:** Moderate policies, validation without blocking
- **Development:** Relaxed policies for rapid iteration

### 3. **Mutations** (`mutations/`)
Auto-remediation policies that modify resources:
- Add missing labels
- Inject default resource limits
- Add Istio sidecar annotations
- Configure network policies

### 4. **Exemptions** (`exemptions/`)
PolicyExceptions for platform components that need to bypass certain policies.

## 🚀 Quick Start

### Prerequisites
- Kyverno installed: `cd ..\cw-tools && .\install-kyverno.ps1`
- Kubernetes cluster access
- kubectl configured

### Deploy All Policies

```powershell
# Deploy all policies
.\deploy.ps1

# Deploy specific category
.\deploy.ps1 -Category cluster-policies

# Dry-run mode
.\deploy.ps1 -DryRun
```

### View Policy Status

```powershell
# List all cluster policies
kubectl get clusterpolicy

# View policy reports
kubectl get policyreport -A

# Check specific policy
kubectl describe clusterpolicy require-labels
```

## 📚 Policy Lifecycle

### Phase 1: Audit Mode (Week 1-2)
All policies start in **Audit** mode:
```yaml
spec:
  validationFailureAction: Audit  # Log violations, don't block
```

**Purpose:** Identify violations without breaking existing deployments

### Phase 2: Monitoring (Week 3)
Review policy reports:
```bash
kubectl get policyreport -A -o yaml
```

Update service configurations to comply with policies.

### Phase 3: Enforcement (Week 4+)
Switch to **Enforce** mode:
```yaml
spec:
  validationFailureAction: Enforce  # Block non-compliant resources
```

Gradually enable enforcement per policy after validation.

## 🎯 Core Policies

### 1. **Require Labels** (`require-labels.yaml`)
Enforces platform naming standards:
- `app.kubernetes.io/name`
- `environment` (dev/staging/prod)
- `region` (us-east-1, etc.)

### 2. **Disallow Latest Tag** (`disallow-latest-tag.yaml`)
Prevents `latest` image tags in staging/prod:
- ✅ Allowed in dev
- ❌ Blocked in staging/prod

### 3. **Require Resource Limits** (`require-resource-limits.yaml`)
Enforces CPU/memory limits:
- Prevents resource exhaustion
- Required for HPA to function

### 4. **Require Probes** (`require-probes.yaml`)
Requires liveness and readiness probes:
- Ensures health checks configured
- Critical for progressive delivery

### 5. **Pod Security Standards** (`require-pod-security.yaml`)
Enforces security best practices:
- Non-root user
- Read-only root filesystem
- No privilege escalation
- Drop ALL capabilities

## 🔐 Security Policies

### Image Security
- Require image signatures (Cosign/Notary)
- Block images from untrusted registries
- Enforce vulnerability scanning

### Network Security
- Require NetworkPolicies in prod
- Enforce Istio mTLS when service mesh enabled
- Validate HTTPRoute configurations

### RBAC
- Restrict ServiceAccount token mounts
- Limit cluster-admin usage
- Validate Role/ClusterRole permissions

## 🎭 Progressive Delivery Policies

### Argo Rollouts Integration
- **Prod must use Rollouts:** Block Deployments in production namespaces
- **Require analysis templates:** Prod Rollouts must have metrics-based validation
- **Validate canary steps:** Ensure proper pause durations and weights

### Example Policy
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: prod-requires-rollouts
spec:
  validationFailureAction: Enforce
  rules:
  - name: no-deployments-in-prod
    match:
      resources:
        kinds: [Deployment]
        namespaces: [prod]
    validate:
      message: "Production must use Argo Rollouts"
      deny: {}
```

## 🔧 Mutations (Auto-Remediation)

### 1. **Add Platform Labels** (`add-default-labels.yaml`)
Automatically adds:
```yaml
metadata:
  labels:
    app.kubernetes.io/managed-by: argocd
    platform: gitops-platform
```

### 2. **Add Resource Limits** (`add-default-limits.yaml`)
Injects default limits if missing:
```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

### 3. **Inject Istio Annotations** (`inject-istio-annotations.yaml`)
Adds sidecar annotations when `cw-istio.enabled: true`

## 🎛️ Policy Configuration

### Severity Levels
```yaml
metadata:
  labels:
    policy.kyverno.io/severity: high|medium|low
    policy.kyverno.io/category: security|best-practices|governance
```

### Environment-Specific Policies
```yaml
# Apply only to production
match:
  resources:
    namespaces:
    - prod
```

### Exemptions
```yaml
# cw-policies/exemptions/platform-components.yaml
apiVersion: kyverno.io/v2beta1
kind: PolicyException
metadata:
  name: platform-exemptions
spec:
  exceptions:
  - policyName: require-resource-limits
    ruleNames:
    - require-limits
  match:
    any:
    - resources:
        namespaces:
        - kyverno
        - argocd
        - istio-system
```

## 📊 Monitoring & Reporting

### Prometheus Metrics
```promql
# Policy violations
kyverno_policy_results_total{policy_name="require-labels",status="fail"}

# Admission requests
kyverno_admission_requests_total

# Policy execution duration
kyverno_policy_execution_duration_seconds
```

### Policy Reports
```bash
# View all violations
kubectl get policyreport -A

# Detailed report for namespace
kubectl describe policyreport -n prod

# Export to JSON
kubectl get policyreport -n prod -o json > violations.json
```

### Dashboard (Optional)
Install Kyverno UI:
```bash
helm install kyverno-ui kyverno/kyverno-ui -n kyverno
kubectl port-forward -n kyverno svc/kyverno-ui 8080:80
# Access: http://localhost:8080
```

## 🔄 GitOps Integration

### ArgoCD Application
Policies are deployed via ArgoCD:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kyverno-policies
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/YOUR_ORG/gitops-platform.git
    path: cw-policies/kyverno
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
```

### Policy as Code
- All policies versioned in Git
- Changes require PR review
- Automated testing via CI/CD
- Progressive rollout (Audit → Enforce)

## 🎓 Policy Development

### Creating New Policies

1. **Create policy file:**
```yaml
# cluster-policies/my-policy.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: my-policy
  labels:
    policy.kyverno.io/severity: medium
    policy.kyverno.io/category: best-practices
spec:
  validationFailureAction: Audit  # Start with Audit
  background: true  # Scan existing resources
  rules:
  - name: my-rule
    match:
      resources:
        kinds: [Deployment]
    validate:
      message: "Custom validation message"
      pattern:
        spec:
          # Your validation logic
```

2. **Test policy:**
```bash
kubectl apply -f cluster-policies/my-policy.yaml --dry-run=server
```

3. **Deploy and monitor:**
```bash
kubectl apply -f cluster-policies/my-policy.yaml
kubectl get policyreport -A
```

4. **Switch to Enforce after validation:**
```yaml
spec:
  validationFailureAction: Enforce
```

### Policy Testing
```bash
# Test against sample manifest
kyverno apply cluster-policies/my-policy.yaml \
  --resource sample-deployment.yaml

# Generate policy report
kyverno apply cluster-policies/ \
  --cluster --policy-report
```

## 📖 Reference

- **Kyverno Documentation:** https://kyverno.io/docs/
- **Policy Library:** https://github.com/kyverno/policies
- **Best Practices:** https://kyverno.io/docs/writing-policies/
- **Platform Naming Standards:** [../NAMING-STANDARDS.md](../NAMING-STANDARDS.md)

## 🚨 Troubleshooting

### Policy Not Applied
```bash
# Check policy status
kubectl get clusterpolicy my-policy -o yaml

# View admission controller logs
kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller
```

### Mutation Not Working
```bash
# Check background controller
kubectl logs -n kyverno -l app.kubernetes.io/component=background-controller

# Verify policy matches resource
kubectl describe clusterpolicy my-mutation
```

### High Resource Usage
```bash
# Disable background scanning for specific policies
spec:
  background: false

# Reduce policy scope
match:
  resources:
    namespaces:
    - prod  # Instead of all namespaces
```

## 📝 Change Log

Track policy changes:
- v1.0.0 - Initial policies (Audit mode)
- v1.1.0 - Added progressive delivery policies
- v1.2.0 - Switched core policies to Enforce mode
- v2.0.0 - Added mutation policies
