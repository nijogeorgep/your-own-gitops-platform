# ApplicationSet + Git Directories Strategy

## Overview
This implementation uses ArgoCD ApplicationSet with Git directory generators to automatically discover and deploy services across multiple environments. This pattern scales efficiently to 1000+ services.

## Directory Structure

```
gitops-platform/
├── services/                    # Service definitions (auto-discovered by ApplicationSet)
│   ├── nginx/
│   │   ├── base-values.yaml    # Shared baseline configuration
│   │   ├── values-dev.yaml     # Dev environment overrides
│   │   ├── values-staging.yaml # Staging environment overrides
│   │   └── values-prod.yaml    # Production environment overrides
│   ├── api-gateway/
│   │   ├── base-values.yaml
│   │   ├── values-dev.yaml
│   │   ├── values-staging.yaml
│   │   └── values-prod.yaml
│   └── <service-name>/         # Add new services here
│       └── ...
├── argocd-bootstrap/           # Bootstrap configuration
│   ├── applicationset-services.yaml  # ApplicationSet that generates all apps
│   └── app-of-apps.yaml        # Root Application (deploys ApplicationSet)
└── cw-service/                 # Shared Helm chart template
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
```

## How It Works

### 1. ApplicationSet Discovery
The ApplicationSet uses a **Git directory generator** that:
- Scans `services/*` for any subdirectories
- For each service found, generates ArgoCD Applications for **dev, staging, prod**
- Automatically picks up new services when directories are added to Git

### 2. Matrix Generation
The ApplicationSet combines two generators:
- **Git directories**: Discovers all services (`services/nginx`, `services/api-gateway`, etc.)
- **Environment list**: Defines target environments (dev, staging, prod)

Result: For each service, creates 3 Applications (one per environment)

Example generated Applications:
- `nginx-dev` → deploys to `dev` namespace (auto-sync)
- `nginx-staging` → deploys to `staging` namespace (auto-sync)
- `nginx-prod` → deploys to `prod` namespace (manual sync)

### 3. Values File Layering
Each generated Application uses Helm with two values files:
1. `base-values.yaml` - Shared configuration across all environments
2. `values-<env>.yaml` - Environment-specific overrides

ArgoCD merges these files (override takes precedence).

## Getting Started

### Prerequisites
- ArgoCD installed in cluster
- Git repository with this structure
- cw-service Helm chart deployed

### Initial Setup

1. **Push to Git repository:**
   ```bash
   git add services/ argocd-bootstrap/
   git commit -m "Add ApplicationSet GitOps structure"
   git push origin main
   ```

2. **Update Git URLs:**
   Edit these files and replace `YOUR_ORG` with your Git repository:
   - [argocd-bootstrap/applicationset-services.yaml](argocd-bootstrap/applicationset-services.yaml)
   - [argocd-bootstrap/app-of-apps.yaml](argocd-bootstrap/app-of-apps.yaml)

3. **Deploy the bootstrap Application:**
   ```bash
   kubectl apply -f argocd-bootstrap/app-of-apps.yaml
   ```

4. **Verify ApplicationSet:**
   ```bash
   # Check ApplicationSet is created
   kubectl get applicationset -n argocd
   
   # View generated Applications
   kubectl get applications -n argocd -l managed-by=applicationset
   
   # Should show: nginx-dev, nginx-staging, nginx-prod
   ```

### Adding a New Service

1. **Create service directory:**
   ```bash
   mkdir -p services/my-service
   ```

2. **Create values files:**
   ```bash
   # Base configuration
   cat > services/my-service/base-values.yaml <<EOF
   replicaCount: 2
   image:
     repository: my-org/my-service
     tag: "latest"
   service:
     port: 8080
   EOF
   
   # Dev environment
   cat > services/my-service/values-dev.yaml <<EOF
   environment: dev
   region: us-east-1
   replicaCount: 1
   EOF
   
   # Staging environment
   cat > services/my-service/values-staging.yaml <<EOF
   environment: staging
   region: us-east-1
   replicaCount: 2
   EOF
   
   # Production environment
   cat > services/my-service/values-prod.yaml <<EOF
   environment: prod
   region: us-east-1
   replicaCount: 3
   image:
     tag: "v1.0.0"
   EOF
   ```

3. **Commit and push:**
   ```bash
   git add services/my-service/
   git commit -m "Add my-service deployment configuration"
   git push origin main
   ```

4. **ApplicationSet auto-generates Applications:**
   Within 3 minutes, ArgoCD will:
   - Detect the new `services/my-service` directory
   - Create Applications: `my-service-dev`, `my-service-staging`, `my-service-prod`
   - Deploy to respective namespaces

5. **Verify deployment:**
   ```bash
   kubectl get applications -n argocd | grep my-service
   kubectl get pods -n dev -l app.kubernetes.io/name=my-service
   ```

## Naming Convention

Resources follow the pattern: **`<app-name>-<environment>-<region>`**

Examples:
- Service `nginx` in `dev` environment → `nginx-dev-us-east-1`
- Service `api-gateway` in `prod` → `api-gateway-prod-us-east-1`

This is controlled by the `cw-service` Helm chart's naming helpers in [cw-service/templates/_helpers.tpl](../cw-service/templates/_helpers.tpl).

## Environment-Specific Behavior

### Dev Environment
- **Auto-sync**: Enabled (immediate deployment on Git changes)
- **Self-heal**: Enabled (reverts manual kubectl changes)
- **Resources**: Minimal (1 replica, low CPU/memory)
- **Namespace**: `dev`

### Staging Environment
- **Auto-sync**: Enabled
- **Self-heal**: Enabled
- **Resources**: Medium (2-5 replicas, autoscaling)
- **Namespace**: `staging`

### Production Environment
- **Auto-sync**: **Disabled** (manual approval required)
- **Self-heal**: Enabled
- **Resources**: High (3-10 replicas, strict limits)
- **Security**: Enhanced (non-root, read-only filesystem)
- **Namespace**: `prod`

## Scaling to 1000+ Services

This pattern handles large-scale deployments efficiently:

### Performance
- **Single ApplicationSet** manages all services (not 3000 individual Application manifests)
- Git directory scan is incremental (only checks changed paths)
- ArgoCD refresh interval: 3 minutes (configurable)

### Organization
- Each team owns their service directory in `services/`
- No central coordination needed for adding services
- Self-service: Teams commit values files, ApplicationSet auto-deploys

### Best Practices
1. **Repository structure:**
   - Option A: Monorepo with all services in one repo (simpler)
   - Option B: Multiple repos with ApplicationSet per repo (team isolation)

2. **Resource limits:**
   - Set ArgoCD controller memory to 4Gi+ for large clusters
   - Enable application sharding for 500+ apps
   - Use ArgoCD notifications for sync status

3. **Git workflow:**
   - Use PR reviews for values file changes
   - Automated testing in CI (helm lint, kubeval)
   - CODEOWNERS file for service directories

## Monitoring & Troubleshooting

### View ApplicationSet status:
```bash
kubectl describe applicationset platform-services -n argocd
```

### Check generated Applications:
```bash
kubectl get applications -n argocd -l managed-by=applicationset
```

### View sync status:
```bash
argocd app list
argocd app get nginx-dev
```

### Force ApplicationSet refresh:
```bash
kubectl patch applicationset platform-services -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}'
```

### Common issues:

**Applications not created:**
- Check ApplicationSet status: `kubectl describe applicationset platform-services -n argocd`
- Verify Git repository URL is correct
- Ensure services directory structure matches `services/*` pattern

**Sync failures:**
- Check Application events: `argocd app get <app-name>`
- Validate values files: `helm template cw-service -f services/<service>/base-values.yaml -f services/<service>/values-dev.yaml`
- Review ArgoCD logs: `kubectl logs -n argocd deploy/argocd-application-controller`

**Manual sync required for prod:**
- This is intentional (safety gate)
- Sync via UI: ArgoCD dashboard → Select app → Sync
- Or CLI: `argocd app sync <app-name>`

## Advanced Features

### Multi-Region Deployment
Extend the matrix generator to include regions:
```yaml
- list:
    elements:
      - env: prod
        region: us-east-1
        cluster: https://prod-us-east-1.k8s.local
      - env: prod
        region: eu-west-1
        cluster: https://prod-eu-west-1.k8s.local
```

### Canary Deployments
Add Argo Rollouts integration in service values:
```yaml
# values-prod.yaml
rollout:
  enabled: true
  strategy: canary
  steps:
    - setWeight: 10
    - pause: {duration: 5m}
    - setWeight: 50
    - pause: {duration: 10m}
```

### Service Dependencies
Use sync waves for ordered deployment:
```yaml
# base-values.yaml
argocd:
  syncOptions:
    - syncWave: "5"  # Database deploys first (wave 0), app deploys later
```

## Migration from Existing Setup

If you have existing ArgoCD Applications:

1. **Export current configuration:**
   ```bash
   argocd app get nginx-dev -o yaml > backup-nginx-dev.yaml
   ```

2. **Create service directory with equivalent values:**
   Extract values from existing Application spec into `services/nginx/values-dev.yaml`

3. **Deploy ApplicationSet:**
   ```bash
   kubectl apply -f argocd-bootstrap/app-of-apps.yaml
   ```

4. **Verify new Applications created:**
   ```bash
   kubectl get app nginx-dev -n argocd
   ```

5. **Delete old Application (ArgoCD will recreate from ApplicationSet):**
   ```bash
   argocd app delete nginx-dev --cascade=false
   ```

## References

- [ArgoCD ApplicationSet Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- [Git Directory Generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/)
- [Matrix Generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Matrix/)
- [cw-service Helm Chart](../cw-service/README.md)
