# Custom Namespace Management

The `cw-service` chart now supports creating and managing custom namespaces with full governance capabilities.

## Quick Start

### Basic Namespace Creation

```yaml
# values-with-namespace.yaml
namespace:
  create: true  # Chart will create the namespace

nameOverride: "myapp"
environment: "dev"
```

```powershell
helm install myapp ./cw-service -f values-with-namespace.yaml
# Creates namespace 'dev' and deploys resources into it
```

### Custom Namespace with Labels

```yaml
namespace:
  create: true
  labels:
    environment: production
    team: platform-engineering
    cost-center: eng-001
  annotations:
    owner: "team@example.com"
    description: "Production workloads"
```

## When to Use Namespace Management

### ✅ Use `namespace.create: true` When:

1. **Single-tenant deployments** - One application owns the entire namespace
2. **Full lifecycle management** - Namespace is part of the application
3. **Resource governance needed** - Apply quotas and limits at namespace level
4. **Custom metadata required** - Need specific labels/annotations
5. **Isolated environments** - Dev/staging/prod isolation per app

### ❌ Don't Use `namespace.create: true` When:

1. **Multi-tenant namespaces** - Multiple apps share one namespace
2. **Existing namespaces** - Namespace managed externally (e.g., cluster-admin)
3. **GitOps with multiple releases** - Multiple Helm releases in same namespace
4. **Deletion concerns** - Don't want namespace deleted with Helm release

## Resource Governance

### ResourceQuota - Total Namespace Limits

Prevents resource exhaustion by limiting total consumption:

```yaml
namespace:
  create: true
  resourceQuota:
    enabled: true
    hard:
      # CPU/Memory quotas
      requests.cpu: "10"          # Max 10 CPUs requested
      limits.cpu: "20"            # Max 20 CPUs limit
      requests.memory: "20Gi"     # Max 20GB requested
      limits.memory: "40Gi"       # Max 40GB limit
      
      # Object count quotas
      pods: "50"                  # Max 50 pods
      services: "10"              # Max 10 services
      persistentvolumeclaims: "5" # Max 5 PVCs
      configmaps: "20"
      secrets: "20"
```

**Use case:** Production namespaces with strict capacity planning

### LimitRange - Default Container Limits

Provides defaults and boundaries for containers:

```yaml
namespace:
  create: true
  limitRange:
    enabled: true
    limits:
      - type: Container
        default:           # Applied if not specified
          cpu: 500m
          memory: 512Mi
        defaultRequest:    # Applied if not specified
          cpu: 100m
          memory: 128Mi
        max:               # Hard maximum
          cpu: 2000m
          memory: 2Gi
        min:               # Hard minimum
          cpu: 50m
          memory: 64Mi
```

**Use case:** Prevent misconfigured pods, enforce resource discipline

## Complete Examples

### Example 1: Production App with Governance

```yaml
# File: services/myapp/values-prod.yaml
nameOverride: "myapp"
environment: "prod"
region: "us-east-1"

namespace:
  create: true
  labels:
    environment: production
    team: backend
    compliance: soc2
  annotations:
    owner: "backend-team@example.com"
    runbook: "https://wiki.internal/myapp"
  
  resourceQuota:
    enabled: true
    hard:
      requests.cpu: "8"
      limits.cpu: "16"
      requests.memory: "16Gi"
      limits.memory: "32Gi"
      pods: "30"
  
  limitRange:
    enabled: true
    limits:
      - type: Container
        default:
          cpu: 500m
          memory: 512Mi
        max:
          cpu: 2000m
          memory: 2Gi

replicaCount: 3
# ... rest of config
```

**Deploy:**
```powershell
helm install myapp-prod ./cw-service -f services/myapp/values-prod.yaml
```

**What gets created:**
- Namespace: `prod` with custom labels/annotations
- ResourceQuota: `prod-quota` limiting total resources
- LimitRange: `prod-limits` with default container limits
- Deployment, Service, etc. in `prod` namespace

### Example 2: Shared Development Namespace

```yaml
# File: services/shared/values-dev.yaml
nameOverride: "shared"
environment: "dev"

namespace:
  create: true
  name: "shared-dev"  # Override default namespace name
  
  labels:
    environment: development
    tenant: shared
  
  resourceQuota:
    enabled: true
    hard:
      requests.cpu: "20"      # Generous for development
      limits.cpu: "40"
      requests.memory: "40Gi"
      pods: "100"
  
  limitRange:
    enabled: true
    limits:
      - type: Container
        default:
          cpu: 200m    # Small defaults
          memory: 256Mi
        max:
          cpu: 1000m   # Prevent single container hogging
          memory: 1Gi

# Each service deployed here gets small defaults
replicaCount: 1
```

**Usage pattern:**
```powershell
# First deployment creates the namespace
helm install svc1 ./cw-service -f services/shared/values-dev.yaml

# Subsequent deployments use existing namespace (namespace.create: false)
helm install svc2 ./cw-service -f values-dev-svc2.yaml -n shared-dev
```

### Example 3: External Namespace (No Creation)

```yaml
# File: values-external-ns.yaml
nameOverride: "myapp"
environment: "prod"

namespace:
  create: false  # Namespace exists, managed by cluster admin
  # No quotas/limits - managed externally

replicaCount: 3
# ... rest of config
```

**Deploy to existing namespace:**
```powershell
kubectl create namespace prod  # Created separately

helm install myapp ./cw-service -f values-external-ns.yaml -n prod
```

## GitOps Integration (ArgoCD)

### Pattern 1: ArgoCD Creates Namespace

```yaml
# cw-argo-bootstrap/applicationset-services.yaml
spec:
  template:
    spec:
      destination:
        namespace: "{{ env }}"  # ArgoCD creates namespace
      syncPolicy:
        syncOptions:
          - CreateNamespace=true
```

**Values file:**
```yaml
namespace:
  create: false  # ArgoCD handles namespace creation
```

### Pattern 2: Chart Creates Namespace

```yaml
# services/myapp/values-prod.yaml
namespace:
  create: true
  labels:
    managed-by: argocd
    environment: production
```

**ArgoCD Application:**
```yaml
spec:
  destination:
    server: https://kubernetes.default.svc
    # No namespace specified - chart creates it
```

⚠️ **Warning:** If Helm release is deleted, namespace is also deleted unless you use:
```yaml
metadata:
  annotations:
    helm.sh/resource-policy: keep
```

## Helm Commands

### Install with Namespace Creation

```powershell
# Chart creates namespace
helm install myapp ./cw-service -f values-with-ns.yaml

# Or explicitly specify (override)
helm install myapp ./cw-service -f values-with-ns.yaml -n custom-ns
```

### Upgrade Namespace Configuration

```powershell
# Update namespace labels/quotas
helm upgrade myapp ./cw-service -f values-with-ns-updated.yaml
```

### Delete Release (Keep Namespace)

Add annotation to namespace template:
```yaml
# templates/namespace.yaml
{{- if .Values.namespace.create -}}
apiVersion: v1
kind: Namespace
metadata:
  name: {{ include "cw-service.namespace" . }}
  annotations:
    helm.sh/resource-policy: keep  # Prevents deletion
```

## Troubleshooting

### Namespace Already Exists

**Error:** `Error: namespaces "dev" already exists`

**Solution:**
```yaml
namespace:
  create: false  # Use existing namespace
```

### Quota Exceeded

**Error:** `exceeded quota: requests.cpu=10`

**Solution:** Increase quota or reduce resource requests:
```yaml
namespace:
  resourceQuota:
    hard:
      requests.cpu: "20"  # Increase
```

### Multiple Releases Conflict

**Problem:** Two Helm releases try to create same namespace

**Solution:** Only first release creates namespace:
```yaml
# Release 1
namespace:
  create: true

# Release 2 (same namespace)
namespace:
  create: false
```

### Namespace Not Deleted After helm uninstall

**Cause:** `helm.sh/resource-policy: keep` annotation

**Solution:** Manually delete:
```powershell
kubectl delete namespace prod
```

## Best Practices

1. **Production:** Always use ResourceQuota and LimitRange
2. **Development:** Use generous quotas, small default limits
3. **Shared namespaces:** First release creates, others reuse
4. **Labels:** Add team, environment, cost-center for billing
5. **Annotations:** Document owner, runbook, Slack channel
6. **Keep strategy:** Use for production namespaces
7. **GitOps:** Let ArgoCD create namespaces, chart adds quotas

## See Also

- [values-custom-namespace.yaml](examples/values-custom-namespace.yaml) - Full example with governance
- [values-multi-tenant-namespace.yaml](examples/values-multi-tenant-namespace.yaml) - Shared namespace pattern
- [Kubernetes ResourceQuotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Kubernetes LimitRanges](https://kubernetes.io/docs/concepts/policy/limit-range/)
