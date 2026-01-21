# Kargo Progressive Delivery - At Scale Pattern

Automated promotion workflows for 100+ services using isolated Kargo Projects.

## Architecture

Each service gets its own **isolated Kargo namespace** (`kargo-<service-name>`) containing:
- **1 Project** - Promotion policies (auto dev→staging, manual staging→prod)
- **1 Warehouse** - Watches container registry for new images
- **3 Stages** - dev, staging, prod progression

### Benefits of Isolation

| Benefit | Description |
|---------|-------------|
| ✅ **Isolated Blast Radius** | Service A promotion failure doesn't affect Service B |
| ✅ **Simple RBAC** | Team-based namespace permissions (no complex label selectors) |
| ✅ **Clear Audit Trail** | Per-service promotion history (not 1000+ promotions in one namespace) |
| ✅ **Scalability** | Distributes resources across namespaces (avoids etcd performance issues) |
| ✅ **UI Performance** | Kargo UI loads 3-5 resources per project (not 400+ in shared namespace) |

## Directory Structure

```
cw-kargo/
├── templates/                       # Kargo resource templates
│   ├── namespace.yaml.template      # Namespace definition
│   ├── project.yaml.template        # Project with promotion policies
│   ├── warehouse.yaml.template      # Image registry subscription
│   └── stages.yaml.template         # 3-stage progression (dev→staging→prod)
├── projects/                        # Generated resources (one dir per service)
│   ├── nginx/
│   │   ├── namespace.yaml
│   │   ├── project.yaml
│   │   ├── warehouse.yaml
│   │   └── stages.yaml
│   └── api-gateway/
│       └── ...
├── generate-kargo-resources.ps1    # Generate resources from templates
├── deploy.ps1                       # Deploy to cluster
└── README.md
```

## Quick Start

### 1. Generate Kargo Resources

**For all services:**
```powershell
.\generate-kargo-resources.ps1 `
    -ImageRepository your-registry.io `
    -GitRepoURL https://github.com/YOUR_ORG/gitops-platform.git
```

**For specific service:**
```powershell
.\generate-kargo-resources.ps1 -ServiceName nginx
```

**With custom settings:**
```powershell
.\generate-kargo-resources.ps1 `
    -ImageRepository myregistry.azurecr.io `
    -GitRepoURL https://github.com/myorg/platform.git `
    -Force  # Overwrite existing files
```

This scans `services/*` directories and generates:
- `projects/nginx/namespace.yaml` - Isolated namespace `kargo-nginx`
- `projects/nginx/project.yaml` - Promotion policies
- `projects/nginx/warehouse.yaml` - Watches `your-registry.io/nginx`
- `projects/nginx/stages.yaml` - Dev, staging, prod stages

### 2. Review Generated Files

```powershell
# Check generated resources
Get-ChildItem -Path projects -Recurse -Filter *.yaml

# Review specific service
Get-Content projects/nginx/project.yaml
Get-Content projects/nginx/stages.yaml
```

### 3. Deploy to Cluster

**Deploy all services:**
```powershell
.\deploy.ps1
```

**Deploy specific service:**
```powershell
.\deploy.ps1 -ServiceName nginx
```

**Skip namespace creation (if already exists):**
```powershell
.\deploy.ps1 -SkipNamespace
```

### 4. Verify Deployment

```powershell
# List all Kargo Projects
kubectl get projects --all-namespaces

# Check specific service
kubectl get warehouses,stages -n kargo-nginx

# View stage details
kubectl describe stage dev -n kargo-nginx

# Check promotion history
kubectl get promotions -n kargo-nginx
```

### 5. Access Kargo UI

```powershell
# If using platform gateway
http://localhost:8080/kargo

# Or direct port-forward
kubectl port-forward -n kargo svc/kargo-api 8080:80
```

## Promotion Workflow

### Automatic Flow (Dev → Staging)

```
New Image Pushed to Registry
         ↓
Warehouse detects new image
         ↓
Auto-creates Freight object
         ↓
Stage "dev" auto-promotes
         ↓
Updates services/<name>/values-dev.yaml
         ↓
Git commit & push
         ↓
ArgoCD syncs (within 3 minutes)
         ↓
Dev environment updated
         ↓
Stage "staging" auto-promotes (policy enabled)
         ↓
Updates services/<name>/values-staging.yaml
         ↓
Staging environment updated
```

### Manual Approval (Staging → Prod)

```powershell
# View available freight in staging
kubectl get freight -n kargo-nginx

# Manually promote to production
kubectl kargo promote --project nginx --stage prod --freight <freight-name>

# Or via Kargo UI: http://localhost:8080/kargo
# Click project → Select stage "prod" → Promote
```

## Configuration

### Promotion Policies

Edit `templates/project.yaml.template` to customize:

```yaml
spec:
  promotionPolicies:
  - stage: staging
    autoPromotionEnabled: true   # Auto dev→staging
  - stage: prod
    autoPromotionEnabled: false  # Manual staging→prod
```

### Image Version Constraints

Edit `templates/warehouse.yaml.template`:

```yaml
spec:
  subscriptions:
  - image:
      repoURL: {{IMAGE_REPOSITORY}}
      semverConstraint: ^1.0.0    # Major version 1.x.x
      # semverConstraint: ~1.2.0  # Patch versions 1.2.x
      # semverConstraint: ^0.0.0  # Any version (dev)
      discoveryLimit: 10           # Keep last 10 images
```

### Git Repository Settings

Update in `generate-kargo-resources.ps1` or pass as parameter:

```powershell
$GitRepoURL = "https://github.com/YOUR_ORG/gitops-platform.git"
```

Ensure Kargo has Git credentials configured (see Kargo documentation).

## Integration with Existing Platform

### With Argo Events + Workflows

```
Code Push → Argo Events → Argo Workflows → Build Image → Push to Registry
                                                             ↓
                                              Kargo Warehouse detects new image
                                                             ↓
                                              Auto-promote to dev stage
                                                             ↓
                                              Update services/*/values-dev.yaml
                                                             ↓
                                              ArgoCD ApplicationSet syncs
```

### With ArgoCD ApplicationSet

Kargo updates the same `services/*/values-*.yaml` files that ApplicationSet watches:

```yaml
# ApplicationSet watches these files:
services/nginx/values-dev.yaml
services/nginx/values-staging.yaml
services/nginx/values-prod.yaml

# Kargo promotions update these files via Git commits
# ArgoCD detects changes and syncs (within 3 minutes)
```

## RBAC Examples

### Team-Based Access

```yaml
# Grant team-nginx full access to their Kargo namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-nginx-kargo-admin
  namespace: kargo-nginx
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin  # Full access to namespace
subjects:
  - kind: Group
    name: team-nginx
    apiGroup: rbac.authorization.k8s.io
```

### Read-Only Access

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developers-readonly
  namespace: kargo-nginx
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
  - kind: Group
    name: developers
    apiGroup: rbac.authorization.k8s.io
```

## Troubleshooting

### Check Warehouse Status

```powershell
kubectl get warehouse nginx -n kargo-nginx -o yaml

# Look for:
# - status.lastHandledCommit
# - status.discoveredImages
```

### Check Stage Status

```powershell
kubectl get stage dev -n kargo-nginx -o yaml

# Look for:
# - status.currentFreight
# - status.health
```

### View Promotion Logs

```powershell
# Get recent promotions
kubectl get promotions -n kargo-nginx --sort-by=.metadata.creationTimestamp

# Describe specific promotion
kubectl describe promotion <promotion-name> -n kargo-nginx
```

### Debug Failed Promotion

```powershell
# Check promotion status
kubectl get promotion <name> -n kargo-nginx -o jsonpath='{.status.phase}'

# View error details
kubectl get promotion <name> -n kargo-nginx -o jsonpath='{.status.message}'
```

## Scaling Considerations

### 100+ Services

- **Namespace count**: 100+ namespaces (one per service) - ✅ Kubernetes handles this well
- **Resource count**: ~400 resources total (4 per service) - ✅ Well distributed
- **etcd impact**: Minimal (resources distributed across namespaces)
- **UI performance**: Fast (scoped queries per namespace)

### 1000+ Services

- Consider **cluster sharding** (multiple Kargo instances)
- Use **Kargo Federation** (if available)
- Implement **namespace quotas** to prevent resource exhaustion

## Adding New Services

When you add a new service to `services/<new-service>/`:

```powershell
# 1. Generate Kargo resources
.\generate-kargo-resources.ps1 -ServiceName new-service

# 2. Review generated files
Get-Content projects/new-service/*.yaml

# 3. Deploy
.\deploy.ps1 -ServiceName new-service

# 4. Verify
kubectl get all -n kargo-new-service
```

## Cleanup

### Remove Specific Service

```powershell
kubectl delete namespace kargo-nginx
Remove-Item -Recurse projects/nginx
```

### Remove All Kargo Resources

```powershell
# Delete all kargo-* namespaces
kubectl get namespaces -l app.kubernetes.io/managed-by=kargo -o name | kubectl delete -f -

# Clean generated files
Remove-Item -Recurse projects/*
```

## References

- [Kargo Official Documentation](https://kargo.akuity.io/)
- [Kargo Promotion Mechanics](https://kargo.akuity.io/concepts/promotion/)
- [Kargo Git-Based Workflows](https://kargo.akuity.io/how-to/working-with-git/)
- [Integration with ArgoCD](https://kargo.akuity.io/how-to/integrating-with-argocd/)
