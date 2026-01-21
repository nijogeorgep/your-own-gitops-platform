# Kyverno Policy Catalog

Complete list of policies deployed in this platform.

## 📋 Policy Summary

| Category | Policy | Severity | Mode | Description |
|----------|--------|----------|------|-------------|
| **Cluster Policies** | | | | |
| Labels | require-labels | Medium | Audit | Enforce platform naming standards (app.kubernetes.io/name, environment, region) |
| Images | disallow-latest-tag | High | Audit | Block 'latest' image tags in staging/prod |
| Resources | require-resource-limits | Medium | Audit | Require CPU/memory limits and requests |
| Health | require-probes | Medium | Audit | Require liveness/readiness probes |
| Security | require-pod-security | High | Audit | Enforce pod security standards (non-root, read-only FS, drop capabilities) |
| **Progressive Delivery** | | | | |
| Rollouts | prod-requires-rollouts | High | Audit | Block standard Deployments in prod (require Argo Rollouts) |
| Analysis | require-rollout-analysis | High | Audit | Require AnalysisTemplates for prod Rollouts |
| Canary | validate-canary-steps | Medium | Audit | Validate pause durations between canary steps |
| **Service Mesh** | | | | |
| Security | require-istio-mtls | High | Audit | Require Istio mTLS for prod services |
| **Mutations** | | | | |
| Labels | add-default-labels | Low | N/A | Auto-inject managed-by and part-of labels |
| Resources | add-default-limits | Medium | N/A | Inject default resource limits if missing |
| Istio | inject-istio-annotations | Low | N/A | Auto-inject Istio sidecar annotations |
| **Exemptions** | | | | |
| Platform | platform-components | N/A | N/A | Exempt platform namespaces (argocd, istio-system, kyverno) |
| Development | development-exemptions | N/A | N/A | Relax policies for dev environment |

## 📂 File Structure

```
cw-policies/
├── README.md                                    # Policy management guide
├── deploy.ps1                                   # Deployment script
└── kyverno/
    ├── cluster-policies/
    │   ├── require-labels.yaml                  # Platform label requirements
    │   ├── disallow-latest-tag.yaml             # Block latest tags
    │   ├── require-resource-limits.yaml         # Resource governance
    │   ├── require-probes.yaml                  # Health check enforcement
    │   ├── require-pod-security.yaml            # Pod security standards
    │   ├── prod-requires-rollouts.yaml          # Rollouts enforcement
    │   ├── require-rollout-analysis.yaml        # Analysis requirement
    │   ├── validate-canary-steps.yaml           # Canary validation
    │   └── require-istio-mtls.yaml              # mTLS enforcement
    ├── mutations/
    │   ├── add-default-labels.yaml              # Auto-label injection
    │   ├── add-default-limits.yaml              # Default resource limits
    │   └── inject-istio-annotations.yaml        # Istio annotation injection
    └── exemptions/
        ├── platform-components.yaml             # Platform exemptions
        └── development-exemptions.yaml          # Dev environment exemptions
```

## 🔄 Policy Lifecycle

### Phase 1: Audit Mode (Week 1-2)
**Goal:** Discover existing violations without blocking deployments

```powershell
cd cw-policies
.\deploy.ps1  # Defaults to Audit mode
```

**Actions:**
- Deploy all policies in Audit mode
- Monitor policy reports
- Identify non-compliant resources
- Update services to fix violations

**Monitoring:**
```powershell
# View all policy reports
kubectl get policyreports -A

# View violations
kubectl get policyreport -A -o json | jq '.items[].results[] | select(.result=="fail")'

# Check specific namespace
kubectl get policyreport -n prod -o yaml
```

### Phase 2: Remediation (Week 2-3)
**Goal:** Fix violations and test mutations

**Actions:**
- Update service configurations to comply with policies
- Test mutations (auto-labels, default limits)
- Verify exemptions work correctly
- Create additional exemptions if needed

**Validation:**
```powershell
# Test deployment with violations (should pass in Audit mode)
kubectl apply -f test-deployment.yaml

# Check policy report for that resource
kubectl get policyreport -n <namespace> -o yaml
```

### Phase 3: Enforce Mode (Week 4+)
**Goal:** Block non-compliant resources

```powershell
cd cw-policies
.\deploy.ps1 -Mode Enforce -Force
```

**Actions:**
- Deploy policies in Enforce mode
- Monitor for blocked resources
- Provide guidance to teams on compliance
- Gradually enforce stricter policies

**Monitoring:**
```powershell
# View blocked requests (events)
kubectl get events -n <namespace> --field-selector reason=PolicyViolation

# View policy status
kubectl get clusterpolicies
```

## 🎯 Policy Categories Explained

### Core Policies (Foundation)
**Purpose:** Baseline security and operational excellence

- **require-labels**: Ensures observability and governance
  - Required labels: `app.kubernetes.io/name`, `environment`, `region`
  - Applies to: Deployments, Rollouts, Services, ConfigMaps
  - Impact: Enables metrics filtering, resource tracking

- **disallow-latest-tag**: Prevents unpredictable deployments
  - Blocks: `image: myapp:latest` in staging/prod
  - Allows: Dev environment (rapid iteration)
  - Impact: Ensures reproducible deployments

- **require-resource-limits**: Resource governance
  - Required: CPU/memory limits and requests
  - Applies to: All containers
  - Impact: Prevents resource exhaustion, enables HPA

- **require-probes**: Application health
  - Required: liveness and readiness probes
  - Applies to: Deployments, Rollouts
  - Impact: Enables graceful shutdowns, prevents bad rollouts

- **require-pod-security**: Security baseline
  - Enforces: Non-root user, read-only FS, drop capabilities, no privilege escalation
  - Applies to: Production environment
  - Impact: Reduces attack surface, compliance

### Advanced Policies (Progressive Delivery)
**Purpose:** Enforce safe deployment practices

- **prod-requires-rollouts**: Progressive delivery
  - Blocks: Standard Deployments in prod
  - Requires: Argo Rollouts with canary/blue-green
  - Impact: Prevents risky instant deployments

- **require-rollout-analysis**: Automated validation
  - Requires: AnalysisTemplates in prod Rollouts
  - Enforces: Metrics-driven validation
  - Impact: Prevents deployments without health checks

- **validate-canary-steps**: Gradual rollout
  - Requires: Minimum 5-minute pause between steps
  - Validates: Proper pause durations
  - Impact: Allows time for metric collection

### Service Mesh Policies
**Purpose:** Secure service-to-service communication

- **require-istio-mtls**: Encryption
  - Requires: Istio sidecar and mTLS mode STRICT
  - Applies to: Production services
  - Impact: Ensures encrypted communication

### Mutations (Auto-Remediation)
**Purpose:** Reduce toil, ensure consistency

- **add-default-labels**: Auto-labeling
  - Injects: `app.kubernetes.io/managed-by: helm`, `app.kubernetes.io/part-of: gitops-platform`
  - Impact: Reduces manual configuration

- **add-default-limits**: Resource defaults
  - Injects: 100m/128Mi requests, 500m/512Mi limits (if missing)
  - Impact: Prevents resource starvation, allows override

- **inject-istio-annotations**: Service mesh enrollment
  - Injects: `sidecar.istio.io/inject: true`, Prometheus annotations
  - Applies to: Staging/prod environments
  - Impact: Automatic Istio enrollment

### Exemptions
**Purpose:** Exclude platform components and dev environments

- **platform-components**: Platform exemptions
  - Namespaces: argocd, istio-system, kyverno, cert-manager
  - Rationale: Platform components have different requirements

- **development-exemptions**: Dev relaxation
  - Allows: Latest tags, standard Deployments, relaxed security
  - Namespace: dev
  - Rationale: Enable rapid iteration

## 🔍 Monitoring & Reporting

### Policy Reports
Kyverno generates reports for every namespace:

```powershell
# View all reports
kubectl get policyreports -A

# View specific report
kubectl get policyreport -n prod -o yaml

# Count violations
kubectl get policyreport -A -o json | jq '[.items[].results[] | select(.result=="fail")] | length'
```

### Prometheus Metrics
Kyverno exports metrics (requires Prometheus):

```promql
# Policy violations over time
kyverno_policy_results_total{result="fail"}

# Policy execution duration
kyverno_policy_execution_duration_seconds

# Admission review latency
kyverno_admission_review_duration_seconds
```

### Kyverno UI
Access via port-forward (no installation needed):

```powershell
kubectl port-forward -n kyverno svc/kyverno-reports-controller 8000:8000
# Open: http://localhost:8000
```

## 📚 Additional Resources

- **Platform Documentation:**
  - [README.md](../README.md) - Platform overview and setup
  - [NAMING-STANDARDS.md](../NAMING-STANDARDS.md) - Naming conventions
  - [cw-policies/README.md](README.md) - Policy management guide

- **Kyverno Documentation:**
  - [Kyverno Policies](https://kyverno.io/policies/)
  - [Writing Policies](https://kyverno.io/docs/writing-policies/)
  - [Policy Reports](https://kyverno.io/docs/policy-reports/)

- **Best Practices:**
  - Start with Audit mode
  - Monitor for 1-2 weeks before enforcing
  - Create exemptions for valid exceptions
  - Document policy rationale
  - Test policies in dev first
