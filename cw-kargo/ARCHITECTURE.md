# Kargo Architecture Diagram

## Per-Service Isolation Pattern

```
┌─────────────────────────────────────────────────────────────────────┐
│                    GitOps Platform (100+ Services)                  │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  Service: nginx │  │ Service: api-gw │  │ Service: auth   │  ... (100+)
└────────┬────────┘  └────────┬────────┘  └────────┬────────┘
         │                    │                     │
         ▼                    ▼                     ▼
┌────────────────┐   ┌────────────────┐   ┌────────────────┐
│ kargo-nginx    │   │ kargo-api-gw   │   │ kargo-auth     │
│  namespace     │   │  namespace     │   │  namespace     │
├────────────────┤   ├────────────────┤   ├────────────────┤
│ • Project: 1   │   │ • Project: 1   │   │ • Project: 1   │
│ • Warehouse: 1 │   │ • Warehouse: 1 │   │ • Warehouse: 1 │
│ • Stages: 3    │   │ • Stages: 3    │   │ • Stages: 3    │
│   - dev        │   │   - dev        │   │   - dev        │
│   - staging    │   │   - staging    │   │   - staging    │
│   - prod       │   │   - prod       │   │   - prod       │
│ • Promotions   │   │ • Promotions   │   │ • Promotions   │
│ • Freight      │   │ • Freight      │   │ • Freight      │
└────────────────┘   └────────────────┘   └────────────────┘
        ↕                     ↕                     ↕
┌────────────────────────────────────────────────────────┐
│              Git Repository (services/*)               │
│  • nginx/values-dev.yaml                               │
│  • nginx/values-staging.yaml                           │
│  • nginx/values-prod.yaml                              │
│  • api-gw/values-dev.yaml                              │
│  • ...                                                 │
└────────────────────────────────────────────────────────┘
```

## Complete Promotion Flow

```
┌──────────────┐
│  Developer   │
│  git push    │
└──────┬───────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│              Argo Events (GitHub Webhook)                │
└──────┬───────────────────────────────────────────────────┘
       │ Trigger
       ▼
┌──────────────────────────────────────────────────────────┐
│           Argo Workflows (build-push-image)              │
│  1. Clone repo                                           │
│  2. Build with Kaniko                                    │
│  3. Push to registry: your-registry.io/nginx:abc123      │
└──────┬───────────────────────────────────────────────────┘
       │ New image pushed
       ▼
┌──────────────────────────────────────────────────────────┐
│      Kargo Warehouse (watches registry)                  │
│  namespace: kargo-nginx                                  │
│  - Detects: your-registry.io/nginx:abc123                │
│  - Creates: Freight object                               │
└──────┬───────────────────────────────────────────────────┘
       │ New freight available
       ▼
┌──────────────────────────────────────────────────────────┐
│      Stage: dev (auto-promotion enabled)                 │
│  namespace: kargo-nginx                                  │
│  1. git clone                                            │
│  2. Update services/nginx/values-dev.yaml                │
│     image.tag: "abc123"                                  │
│  3. git commit & push                                    │
└──────┬───────────────────────────────────────────────────┘
       │ Dev promoted (3 min ArgoCD refresh)
       ▼
┌──────────────────────────────────────────────────────────┐
│   ArgoCD Application: nginx-dev (auto-sync)              │
│   - Detects Git change                                   │
│   - Syncs to Kubernetes                                  │
│   - Deploys nginx:abc123 to dev namespace                │
└──────┬───────────────────────────────────────────────────┘
       │ Dev deployed successfully
       ▼
┌──────────────────────────────────────────────────────────┐
│    Stage: staging (auto-promotion enabled)               │
│  namespace: kargo-nginx                                  │
│  - Subscribes to: upstream stage "dev"                   │
│  1. git clone                                            │
│  2. Update services/nginx/values-staging.yaml            │
│     image.tag: "abc123"                                  │
│  3. git commit & push                                    │
└──────┬───────────────────────────────────────────────────┘
       │ Staging promoted (3 min ArgoCD refresh)
       ▼
┌──────────────────────────────────────────────────────────┐
│  ArgoCD Application: nginx-staging (auto-sync)           │
│  - Detects Git change                                    │
│  - Syncs to Kubernetes                                   │
│  - Deploys nginx:abc123 to staging namespace             │
└──────┬───────────────────────────────────────────────────┘
       │ Staging validated
       ▼
┌──────────────────────────────────────────────────────────┐
│    Stage: prod (manual approval required)                │
│  namespace: kargo-nginx                                  │
│  - Subscribes to: upstream stage "staging"               │
│  - WAITING for manual promotion...                       │
└──────┬───────────────────────────────────────────────────┘
       │ Human approval
       ▼
┌──────────────────────────────────────────────────────────┐
│  kubectl kargo promote --project nginx --stage prod      │
│  OR Kargo UI manual click                                │
└──────┬───────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│    Stage: prod promotion executes                        │
│  1. git clone                                            │
│  2. Update services/nginx/values-prod.yaml               │
│     image.tag: "abc123"                                  │
│  3. git commit & push                                    │
└──────┬───────────────────────────────────────────────────┘
       │ Prod promoted (ArgoCD manual sync required)
       ▼
┌──────────────────────────────────────────────────────────┐
│  ArgoCD Application: nginx-prod (manual sync)            │
│  kubectl argo app sync nginx-prod -n argocd              │
│  - Syncs to Kubernetes                                   │
│  - Deploys nginx:abc123 to prod namespace                │
└──────────────────────────────────────────────────────────┘
```

## RBAC Isolation

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                   │
└─────────────────────────────────────────────────────────┘
         │
         ├─────────────────────────────────────────────┐
         │                                             │
         ▼                                             ▼
┌────────────────────┐                      ┌────────────────────┐
│  Team Nginx        │                      │  Team API Gateway  │
│  (AD Group)        │                      │  (AD Group)        │
└────────┬───────────┘                      └────────┬───────────┘
         │                                           │
         │ RoleBinding                               │ RoleBinding
         ▼                                           ▼
┌────────────────────┐                      ┌────────────────────┐
│ kargo-nginx        │                      │ kargo-api-gateway  │
│ namespace          │                      │ namespace          │
│                    │                      │                    │
│ Permissions:       │                      │ Permissions:       │
│ ✓ Full access      │                      │ ✓ Full access     │
│ ✓ Promote stages   │                      │ ✓ Promote stages  │
│ ✓ View freight     │                      │ ✓ View freight    │
│ ✓ View promotions  │                      │ ✓ View promotions │
│                    │                      │                    │
│ Restrictions:      │                      │ Restrictions:      │
│ ✗ No access to     │                      │ ✗ No access to    │
│   kargo-api-gw     │                      │   kargo-nginx      │
└────────────────────┘                      └────────────────────┘

Benefits:
• No cross-team access by default
• Simple namespace-based RBAC (standard Kubernetes pattern)
• No complex label selectors or custom resources
• Easy to audit (kubectl auth can-i --namespace kargo-nginx)
```

## Scaling to 1000+ Services

```
┌─────────────────────────────────────────────────────────┐
│               Single Shared Namespace (❌)              │
│              kargo-all-services                         │
├─────────────────────────────────────────────────────────┤
│  • 1000 Warehouses                                      │
│  • 3000 Stages                                          │
│  • 10,000+ Promotions (accumulated)                     │
│  • 1000+ Freight objects                                │
│                                                         │
│  Problems:                                              │
│  ⚠ etcd performance degradation                         │
│  ⚠ Slow kubectl get operations                          │
│  ⚠ Kargo UI timeout/slowness                            │
│  ⚠ Complex RBAC (label-based selectors)                 │
│  ⚠ Single point of failure                              │
└─────────────────────────────────────────────────────────┘

VS

┌─────────────────────────────────────────────────────────┐
│          Distributed Namespaces (✅)                    │
│    1000 namespaces × 5 resources each                   │
├─────────────────────────────────────────────────────────┤
│  kargo-nginx:          1 Warehouse, 3 Stages, Freight   │
│  kargo-api-gw:         1 Warehouse, 3 Stages, Freight   │
│  kargo-auth:           1 Warehouse, 3 Stages, Freight   │
│  ... (997 more)                                         │
│                                                         │
│  Benefits:                                              │
│  ✓ Fast kubectl operations (scoped to namespace)        │
│  ✓ Kargo UI responsive (loads 5 resources per view)     │
│  ✓ etcd healthy (distributed load)                      │
│  ✓ Simple namespace RBAC                                │
│  ✓ Isolated blast radius                                │
│  ✓ Clear audit trail per service                        │
└─────────────────────────────────────────────────────────┘
```
