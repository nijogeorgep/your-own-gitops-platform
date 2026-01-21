# GitOps Platform - AI Coding Agent Instructions

## Project Overview
This is a **GitOps-focused Kubernetes platform** using ArgoCD for deployment automation, Argo Rollouts for progressive canary releases, and Istio Gateway API for traffic management. The platform uses a **library chart pattern** with `cw-common/` providing shared helpers, `cw-service/` as the main application chart, `cw-istio/` as an optional Istio integration subchart, and `cw-rollout/` as an optional progressive delivery subchart.

**Key Documentation:**
- **[NAMING-STANDARDS.md](../NAMING-STANDARDS.md)** - Complete naming conventions for all platform components

## Architecture & Structure

### Directory Layout
- **`cw-service/`**: Production-ready Helm chart template for Kubernetes service deployments
  - **`charts/cw-common/`**: Library chart with shared Helm helpers (naming, labels, utilities)
  - **`charts/cw-istio/`**: Istio service mesh resources subchart (optional)
  - **`charts/cw-rollout/`**: Argo Rollouts progressive delivery subchart (optional)
- **`cw-argo-bootstrap/`**: ArgoCD ApplicationSet for auto-discovering and deploying all services
- **`cw-events/`**: Argo Events configurations (EventSources + Sensors for CI/CD automation)
- **`cw-workflows/`**: Argo WorkflowTemplates for build/deploy pipelines
- **`cw-kargo/`**: Kargo stage and promotion configurations for progressive delivery
- **`cw-policies/`**: Kyverno policy definitions (admission control, validation, mutation)
- **`cw-tools/`**: Installation scripts for platform components (Istio, ArgoCD, Kargo, Kyverno, etc.)
  - **`cw-gateway/`**: Istio Gateway config for exposing platform UIs
- **`cw-scripts/helm/`**: Helm deployment scripts (install, upgrade, template, uninstall)
- **`services/`**: Service definitions auto-discovered by ApplicationSet (each service = one directory)

### Library Chart Pattern (`cw-common/`)
The `cw-common` chart is a **Helm library chart** (type: library) that provides reusable helpers for all platform charts:

**Available helpers:**
- `cw-common.name` - Extract chart name from configuration
- `cw-common.fullname` - Platform naming standard: `<app>-<env>-<flavor>-<region>`
- `cw-common.chart` - Chart label value
- `cw-common.labels` - Standard Kubernetes labels
- `cw-common.selectorLabels` - Pod selector labels
- `cw-common.serviceAccountName` - ServiceAccount name resolver

**Usage in dependent charts:**
```yaml
# Chart.yaml
dependencies:
  - name: cw-common
    version: 0.1.0
    repository: "file://../cw-common"

# templates/_helpers.tpl (create aliases for backward compatibility)
{{- define "my-chart.fullname" -}}
{{- include "cw-common.fullname" . }}
{{- end }}
```

### Helm Chart Pattern (`cw-service/`)
This chart follows **standard Helm 3 conventions** with advanced networking features and depends on `cw-common` for shared helpers:
This chart follows **standard Helm 3 conventions** with advanced networking features:

**Key templates:**
- [deployment.yaml](cw-service/templates/deployment.yaml) - Standard Deployment with conditional HPA integration
- [httproute.yaml](cw-service/templates/httproute.yaml) - **Gateway API HTTPRoute** support (v1, modern alternative to Ingress)
- [ingress.yaml](cw-service/templates/ingress.yaml) - Traditional Ingress controller support
- [hpa.yaml](cw-service/templates/hpa.yaml) - Autoscaling/v2 HorizontalPodAutoscaler

**Critical pattern:** The chart supports **dual routing options**:
1. Legacy Ingress (`ingress.enabled`)
2. Modern Gateway API HTTPRoute (`httpRoute.enabled`)

Never enable both simultaneously - they're mutually exclusive networking strategies.

## Helm Template Conventions

### Naming & Labels
All resources use helper templates from [_helpers.tpl](cw-service/templates/_helpers.tpl):
- `cw-service.fullname` - Generates resource names following standard: **`<app-name>-<environment>-<flavor>-<region>`** (truncated to 63 chars for DNS compliance)
  - Components assembled from `.Values.nameOverride`, `.Values.environment`, `.Values.flavor`, `.Values.region`
  - **Flavor is optional** - if omitted, uses format: `<app-name>-<environment>-<region>`
  - Empty components are automatically skipped from the final name
  - Override entire pattern with `.Values.fullnameOverride`
- `cw-service.labels` - Standard labels including `helm.sh/chart`, `app.kubernetes.io/version`
- `cw-service.selectorLabels` - Pod selector labels (name + instance)

**Naming examples:**
```yaml
# Full naming with all components
nameOverride: "myapp"
environment: "prod"
flavor: "api"           # Optional - service variant
region: "us-east-1"
# Results in: myapp-prod-api-us-east-1

# Without flavor (most common)
nameOverride: "myapp"
environment: "prod"
region: "us-east-1"
# Results in: myapp-prod-us-east-1

# Minimal (environment only)
environment: "dev"
# Results in: myapp-dev
```

### Conditional Resource Creation
Use `{{- if .Values.X.enabled }}` pattern for all optional resources:
```yaml
{{- if .Values.httpRoute.enabled -}}
# HTTPRoute resource definition
{{- end }}
```

### Variable Capture Pattern
HTTPRoute template demonstrates best practice for template-scoped variables:
```yaml
{{- $fullName := include "cw-service.fullname" . -}}
{{- $svcPort := .Values.service.port -}}
```
Use this pattern when iterating with `range` to maintain access to root context (`.`).

## Gateway API Specifics (Istio)

### HTTPRoute Integration
When working with HTTPRoute ([httproute.yaml](cw-service/templates/httproute.yaml)):
- **Istio Gateway** must be deployed separately (typically via `cw-argo/` manifests)
- Always set `backendRefs` to reference the service created by the chart (`{{ $fullName }}`)
- `parentRefs` connects to Istio Gateway resources (e.g., `istio-system/gateway`)
- Support `filters` for header modification, redirects, traffic splitting (canary routing)
- Rules automatically get backend references even if not specified in values
- For Argo Rollouts integration, HTTPRoute rules work with canary/stable service variants

**Example values structure:**
```yaml
httpRoute:
  enabled: true
  parentRefs:
    - name: gateway
      sectionName: http
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /api
```

## Values.yaml Patterns

### Probe Configuration
Health checks use `{{- with }}` blocks allowing complete override:
```yaml
livenessProbe:
  httpGet:
    path: /
    port: http
```
Users can replace entire probe definition or omit to disable (deployment uses `{{- with .Values.livenessProbe }}`).

### Resource Limits
Intentionally **defaulted to `{}`** - forces conscious resource allocation per environment:
```yaml
resources: {}
  # Uncomment for production
  # limits:
  #   cpu: 100m
```

### Security Contexts
Both `podSecurityContext` and `securityContext` default to empty - security should be environment-specific, not chart-mandated.

### Multi-Protocol Support
Supports multiple ports with different protocols (HTTP/HTTPS, gRPC):
```yaml
service:
  ports:
    - name: http
      port: 80
      targetPort: 8080
      protocol: TCP
    - name: https
      port: 443
      targetPort: 8443
      protocol: TCP
    - name: grpc
      port: 9090
      targetPort: 9090
      protocol: TCP

# For gRPC health checks
livenessProbe:
  grpc:
    port: 9090
readinessProbe:
  grpc:
    port: 9090
```
Backward compatible: if `service.ports` is empty, falls back to single `service.port` (default: 80).

### Environment Variables
Supports both direct environment variables and references from ConfigMaps/Secrets:
```yaml
# Direct environment variables
env:
  - name: ENVIRONMENT
    value: "production"
  - name: SECRET_KEY
    valueFrom:
      secretKeyRef:
        name: app-secrets
        key: secret-key

# Load all keys from ConfigMap/Secret
envFrom:
  - configMapRef:
      name: app-config
  - secretRef:
      name: app-secrets
```
Use `env` for individual variables, `envFrom` to load entire ConfigMaps/Secrets.

## Development Workflows

### Platform Installation (`cw-tools/`)
**Version management:** All tool versions centrally defined in [versions.psd1](cw-tools/versions.psd1)

**Install complete stack:**
```powershell
cd cw-tools
.\install-all.ps1 -Email admin@example.com
```

**Install components individually:**
```powershell
.\install-cert-manager.ps1 -Email admin@example.com  # TLS automation
.\install-istio.ps1                                  # Service mesh
.\install-argocd.ps1                                 # GitOps controller
.\install-argo-rollouts.ps1                          # Progressive delivery
.\install-argo-events.ps1                            # Event automation
.\install-kargo.ps1                                  # Promotion orchestration
.\install-kyverno.ps1                                # Policy enforcement
.\install-headlamp.ps1                               # Kubernetes UI
```

**Override versions:**
```powershell
.\install-istio.ps1 -IstioVersion "1.21.0"
.\install-kargo.ps1 -Version "0.7.0"
```

**Platform Gateway setup (expose UIs via single LoadBalancer):**
```powershell
cd cw-tools/cw-gateway
.\apply.ps1                    # Apply all Gateway configs

# Local development (Docker Desktop/Kind/Minikube)
.\start-gateway.ps1            # Background port-forward (survives terminal close)
# OR
.\port-forward.ps1             # Foreground (keep terminal open)

# Access UIs at http://localhost:8080/argocd, /headlamp, /rollouts, /kargo
```

**Configure ArgoCD for path prefix:**
```powershell
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.basehref":"/argocd","server.rootpath":"/argocd"}}'
kubectl rollout restart deployment argocd-server -n argocd
```

### Testing Helm Charts (`cw-scripts/helm/`)
**PowerShell scripts for rapid Helm development:**

```powershell
cd cw-scripts/helm

# Template rendering (dry-run, no cluster required)
.\template.ps1 -ValuesFile nginx-dev-values.yaml -OutputFile manifests.yaml

# Install with dev values
.\install.ps1 -ReleaseName nginx -ValuesFile nginx-dev-values.yaml -Namespace dev

# Validate without applying
.\install.ps1 -DryRun

# Upgrade existing release
.\upgrade.ps1 -ReleaseName nginx -ValuesFile nginx-prod-values.yaml -Namespace prod

# Upgrade or install if missing
.\upgrade.ps1 -Install

# Preview upgrade changes
.\upgrade.ps1 -DryRun

# Remove release
.\uninstall.ps1 -ReleaseName nginx -Namespace dev
```

**Script parameters:**
- `-ReleaseName`: Helm release name (default: nginx)
- `-ValuesFile`: Values file (default: nginx-dev-values.yaml)
- `-Namespace`: Target namespace (default: default)
- `-DryRun`: Validate without applying
- `-Install`: (upgrade.ps1) Install if release doesn't exist

### Testing Helm Charts (Standard Commands)
```bash
# Template rendering (dry-run)
helm template my-release ./cw-service --values custom-values.yaml

# Validate against Kubernetes API
helm install --dry-run --debug my-release ./cw-service

# Install with specific values
helm install my-release ./cw-service -f custom-values.yaml -n namespace

# Test connection (uses templates/tests/)
helm test my-release -n namespace
```

### Chart Versioning
- Increment `version` in [Chart.yaml](cw-service/Chart.yaml) for template changes
- Update `appVersion` for application image version changes
- Follow semver for `version`, track app versioning separately

## Critical Workflows & Patterns

### Complete Development Lifecycle
**1. Platform Setup (first time):**
```powershell
# Install all platform components
cd cw-tools
.\install-all.ps1 -Email your-email@example.com

# Setup platform gateway for local access
cd cw-gateway
.\start-gateway.ps1

# Deploy Kyverno policies (Audit mode)
cd ..\..\cw-policies
.\deploy.ps1
```

**2. Add New Service:**
```powershell
# Create service directory structure
mkdir services/my-api
cd services/my-api

# Copy template files (refer to SERVICE-TEMPLATE.md)
# - base-values.yaml (shared config)
# - values-dev.yaml (environment: dev, region: us-east-1)
# - values-staging.yaml (environment: staging)
# - values-prod.yaml (environment: prod, pinned image tags)
# - Dockerfile (application container)

# Commit and push
git add services/my-api/
git commit -m "Add my-api service"
git push origin main

# ApplicationSet auto-creates: my-api-dev, my-api-staging, my-api-prod
```

**3. Local Testing Before GitOps:**
```powershell
cd cw-scripts/helm

# Validate templates
.\template.ps1 -ValuesFile ..\..\services\my-api\values-dev.yaml

# Test install locally
.\install.ps1 -ReleaseName my-api-dev -ValuesFile ..\..\services\my-api\values-dev.yaml -Namespace dev

# Verify deployment
kubectl get pods -n dev
kubectl logs -n dev -l app.kubernetes.io/name=my-api-dev

# Cleanup local test
.\uninstall.ps1 -ReleaseName my-api-dev -Namespace dev
```

**4. Deploy via GitOps:**
```powershell
# Update Git URLs (first time only)
# Edit: cw-argo-bootstrap/applicationset-services.yaml
# Edit: cw-argo-bootstrap/app-of-apps.yaml

# Bootstrap ArgoCD ApplicationSet
kubectl apply -f cw-argo-bootstrap/app-of-apps.yaml

# Verify auto-generated Applications
kubectl get applications -n argocd

# Monitor sync status
kubectl get application my-api-dev -n argocd -w
```

**5. Trigger CI/CD Pipeline (Argo Events):**
```powershell
# Deploy event sources and sensors
cd cw-events
.\deploy.ps1

# Push code change triggers workflow:
# Git push → GitHub webhook → Argo Events → Argo Workflows
# → Build image → Update values-dev.yaml → Commit → ArgoCD sync
```

**6. Production Promotion:**
```powershell
# Update production image tag
# Edit services/my-api/values-prod.yaml:
#   image.tag: "v1.2.3"  # Pin to tested version

git commit -am "Promote my-api to prod v1.2.3"
git push origin main

# ArgoCD detects change, requires manual sync for prod
kubectl argo app sync my-api-prod -n argocd
```

**7. Setup Kargo Progressive Delivery (Optional):**
```powershell
cd cw-kargo

# Generate Kargo resources for all services
.\generate-kargo-resources.ps1 `
    -ImageRepository your-registry.io `
    -GitRepoURL https://github.com/YOUR_ORG/gitops-platform.git

# Review generated resources
Get-ChildItem projects -Recurse -Filter *.yaml

# Deploy to cluster
.\deploy.ps1

# Verify
kubectl get projects --all-namespaces
kubectl get warehouses,stages -n kargo-nginx

# After this, promotions are automated:
# New image → Warehouse → Auto dev → Auto staging → Manual prod approval
```

### Environment-Specific Values Pattern
**Base values (shared across all environments):**
```yaml
# services/my-api/base-values.yaml
replicaCount: 2
image:
  repository: myregistry/my-api
  pullPolicy: IfNotPresent
service:
  port: 8080
livenessProbe:
  httpGet:
    path: /health
    port: http
```

**Dev overrides (low resources, auto-sync):**
```yaml
# services/my-api/values-dev.yaml
environment: dev
region: us-east-1
replicaCount: 1
image:
  tag: "latest"  # Latest builds
resources:
  limits:
    cpu: 100m
    memory: 128Mi
autoscaling:
  enabled: false
```

**Prod overrides (high resources, pinned versions):**
```yaml
# services/my-api/values-prod.yaml
environment: prod
region: us-east-1
# flavor: api  # Optional service variant
replicaCount: 3
image:
  tag: "v1.2.3"  # Pinned tested version
resources:
  limits:
    cpu: 500m
    memory: 512Mi
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
```

## GitOps Workflow & Deployment Strategy

### Service Discovery Pattern (`services/` + ApplicationSet)
The platform uses **Git directory-based auto-discovery** for managing multiple services:

**Structure:**
```
services/
├── nginx/
│   ├── base-values.yaml       # Shared baseline for all environments
│   ├── values-dev.yaml        # Dev overrides (environment: dev)
│   ├── values-staging.yaml    # Staging overrides
│   ├── values-prod.yaml       # Prod overrides (pinned versions, higher resources)
│   └── Dockerfile             # Application container build
├── api-gateway/
│   └── ...
└── <new-service>/  # Just add a directory - ApplicationSet auto-discovers!
```

**ApplicationSet auto-generation:**
- Scans `services/*` directories via Git generator
- Matrix combines services × environments (dev, staging, prod)
- Generates ArgoCD Applications: `<service>-<env>` (e.g., `nginx-dev`, `nginx-prod`)
- Each app references `cw-service/` chart + `base-values.yaml` + `values-<env>.yaml`

**To add a new service:**
1. Create `services/your-service/` directory
2. Add `base-values.yaml` + environment overrides (use [SERVICE-TEMPLATE.md](services/SERVICE-TEMPLATE.md))
3. Git commit & push - ApplicationSet auto-creates 3 Applications (dev/staging/prod)
4. ArgoCD syncs automatically (dev/staging) or manually (prod)

### ArgoCD Integration (`cw-argo-bootstrap/`)
**Bootstrap workflow:**
```powershell
# 1. Update Git URLs in applicationset-services.yaml and app-of-apps.yaml
# 2. Deploy root Application
kubectl apply -f cw-argo-bootstrap/app-of-apps.yaml

# 3. Verify ApplicationSet created
kubectl get applicationset -n argocd

# 4. View auto-generated Applications
kubectl get applications -n argocd -l managed-by=applicationset
```

**Sync policies:**
- Dev/staging: Auto-sync enabled (updates deploy immediately)
- Prod: Manual sync required (human approval gate)

**Scalability (1000+ services):**
- Single ApplicationSet manages 3000 Applications (1000 services × 3 environments)
- Git directory generator with 5-minute polling (`requeueAfterSeconds: 300`)
- Enable sharding for 500+ services: `cd cw-argo-bootstrap; .\enable-sharding.ps1 -ApplyChanges`
- Recommended: 3 controller replicas for 1000-3000 apps, 5 replicas for 5000+ apps
- See [SCALABILITY.md](cw-argo-bootstrap/SCALABILITY.md) for detailed analysis

### Argo Events + Workflows CI/CD Pipeline (`cw-events/` + `cw-workflows/`)
**Complete GitOps automation flow:**
```
GitHub Push → EventSource (webhook) → Sensor → WorkflowTemplate → Update Git → ArgoCD Refresh
```

**Components:**
1. **EventSources** ([eventsource-github.yaml](cw-events/eventsource-github.yaml)):
   - Listen for GitHub webhooks (push, PR, release)
   - Calendar triggers for cron jobs (nightly builds)
   
2. **Sensors** ([sensor-image-update.yaml](cw-events/sensor-image-update.yaml)):
   - Map event payload to workflow parameters
   - Trigger Argo WorkflowTemplates with dynamic inputs

3. **WorkflowTemplates** ([cw-workflows/](cw-workflows/)):
   - `build-push-image`: Build with Kaniko (no Docker daemon), push to registry
   - `update-git-values`: Update `values-dev.yaml` with new image tag, git commit/push
   - Workflows are DAGs with dependencies (clone → build → push → update-git)

4. **ArgoCD refresh cycle**:
   - Git directory generator polls every 3 minutes
   - Detects updated values files → triggers sync

**Example workflow trigger:**
- Dev pushes to `main` branch
- GitHub webhook → Argo Events sensor
- Sensor triggers `build-push-image` workflow with commit SHA as tag
- Workflow builds image, updates `services/nginx/values-dev.yaml` with new tag
- Commits & pushes to Git
- ArgoCD detects change (≤3 min) → syncs to Kubernetes

### Argo Rollouts - Progressive Canary Strategy
Deployments use **Argo Rollouts** for safe progressive delivery:
- Replace standard Deployment with Rollout resource in `cw-service/templates/`
- Canary strategy: traffic gradually shifts from stable to canary (e.g., 10% → 25% → 50% → 100%)
- Istio HTTPRoute integration for weighted traffic splitting
- Analysis templates validate canary health (metrics, error rates)
- Automatic rollback on failure, manual promotion gates for production

**Key pattern:** Rollout creates two services (stable/canary), HTTPRoute distributes traffic based on weights.

### Kargo Workflows (`cw-kargo/`) - At Scale Pattern
Kargo orchestrates multi-stage promotions using **isolated per-service projects** for scalability:

**Architecture (100+ services):**
- Each service gets its own namespace: `kargo-<service-name>`
- One Kargo Project per service (isolated blast radius, simple RBAC)
- Template-based generation from `services/*` directories
- Avoids resource explosion in single namespace

**Key files:**
- `templates/*.yaml.template` - Reusable Kargo resource templates
- `generate-kargo-resources.ps1` - Auto-generate from services directory
- `projects/<service>/` - Generated resources per service
- `deploy.ps1` - Deploy all or specific service Kargo resources

**Promotion flow:**
```
New Image → Warehouse detects → Auto-promote to dev → Update values-dev.yaml
         → Auto-promote to staging → Update values-staging.yaml
         → Manual approval for prod → Update values-prod.yaml
```

**Generate and deploy:**
```powershell
cd cw-kargo
.\generate-kargo-resources.ps1 -ImageRepository your-registry.io
.\deploy.ps1  # Creates kargo-nginx, kargo-api-gateway, etc.
```

**Benefits of isolation:**
- ✅ Service A failure doesn't affect Service B
- ✅ Simple namespace-based RBAC (no complex label selectors)
- ✅ Clear per-service audit trail
- ✅ UI performance (3-5 resources per namespace vs 400+ in shared)
- ✅ Scales to 1000+ services without etcd degradation

## Common Modifications

### Adding New Kubernetes Resources
1. Create template in `cw-service/templates/` (e.g., `configmap.yaml`)
2. Add conditional rendering with `.Values.X.enabled`
3. Use helper templates for labels: `{{- include "cw-service.labels" . | nindent 4 }}`
4. Add corresponding values schema in `values.yaml`

### Supporting Additional Networking Options
When adding support for new ingress controllers or service mesh:
- Follow the HTTPRoute pattern for conditional enablement
- Ensure mutual exclusivity with existing routing options
- Document in `values.yaml` comments with links to upstream docs

### Container Configuration
The deployment template uses `.Chart.Name` for container name - keep this consistent. Port configuration links service port to container port via the `http` named port pattern.

### Argo Rollouts - Progressive Delivery Subchart (`cw-rollout/`)
The platform provides **advanced progressive delivery** through the `cw-rollout` subchart with multi-provider analysis:

**Architecture:**
- Optional subchart dependency: `cw-rollout` (condition: `cw-rollout.enabled`)
- Mutually exclusive with standard Deployment (deployment.yaml disabled when `cw-rollout.enabled: true`)
- HPA automatically switches between Deployment/Rollout based on enabled flag
- HTTPRoute/VirtualService traffic routing integration

**Key features:**
1. **Progressive strategies**: Canary (gradual traffic shift), Blue-Green (instant switch)
2. **Analysis templates**: Prometheus, Datadog, New Relic, custom webhooks
3. **Automated rollback**: Metrics-driven validation with configurable thresholds
4. **Experimentation**: A/B testing support with traffic splitting
5. **Scalable to 1000+ services**: Service-level opt-in, no coordination needed

**Service-level enablement:**
```yaml
# services/myapp/values-prod.yaml
cw-rollout:
  enabled: true
  rollout:
    strategy: canary
    canary:
      steps:
        - setWeight: 10
        - pause: {duration: 5m}
        - analysis:
            templates:
              - templateName: prometheus-success-rate
        - setWeight: 50
        - pause: {duration: 10m}
  
  analysisTemplates:
    prometheus:
      enabled: true
      address: http://prometheus.monitoring:9090
      queries:
        successRate:
          enabled: true
          query: |
            sum(rate(http_requests_total{code=~"2.."}[5m])) /
            sum(rate(http_requests_total[5m]))
          threshold: 0.95
```

**Multi-provider analysis pattern:**
```yaml
# Combine Prometheus, Datadog, New Relic, and webhooks
analysisTemplates:
  prometheus:
    enabled: true
    queries:
      successRate: {...}
      errorRate: {...}
      latency: {...}
  
  datadog:
    enabled: true
    queries:
      errorRate: {...}
      latency: {...}
  
  newrelic:
    enabled: true
    queries:
      apdex: {...}
      errorPercentage: {...}
  
  webhook:
    enabled: true
    webhooks:
      customHealthCheck:
        url: https://example.com/health
        jsonPath: "{$.status}"
        successCondition: "result == 'healthy'"
```

**Documentation:**
- [cw-rollout/README.md](cw-service/charts/cw-rollout/README.md) - Complete subchart documentation
- [cw-rollout/examples/](cw-service/charts/cw-rollout/examples/) - Real-world configuration examples
- [cw-service/ROLLOUTS.md](cw-service/ROLLOUTS.md) - Migration guide and best practices

## Naming Standards Across Platform

### Kubernetes Resources (Helm Charts)
**Pattern:** `<app>-<env>-<flavor>-<region>` (flavor optional)
- Applied to: Deployments, Rollouts, Services, ConfigMaps, Secrets
- Generated by: `cw-common.fullname` helper template
- DNS-compliant: Truncated to 63 characters
- Example: `nginx-prod-api-us-east-1` or `nginx-prod-us-east-1`

### Kargo Resources (Progressive Delivery)
**Pattern:** `<service>-<env>-<region>` for Stages, `<service>-warehouse` for Warehouses
- **Stages:** `nginx-dev-us-east-1`, `nginx-staging-us-east-1`, `nginx-prod-us-east-1`
- **Warehouse:** `nginx-warehouse`
- **Project:** `nginx` (namespace: `kargo-nginx`)
- **Labels:** Include `app.kubernetes.io/name`, `app.kubernetes.io/environment`, `app.kubernetes.io/region`
- **Generated:** Via `generate-kargo-resources.ps1 -Region us-east-1`

### Argo Workflows (CI/CD Pipelines)
**Pattern:** WorkflowTemplates are reusable (no naming standard), Workflow instances use `generateName`
- **WorkflowTemplate:** `build-push-image` (reusable template)
- **Workflow Instance:** `image-update-<random>` (ephemeral, auto-generated)
- **Naming:** Workflows reference service name as parameter, not in resource name
- **Rationale:** Templates are shared, instances are short-lived

### Argo Events (Event Automation)
**Pattern:** EventSources and Sensors are cluster/namespace scoped (no service-specific naming)
- **EventSource:** `github`, `calendar` (shared across all services)
- **Sensor:** `image-update-pipeline` (triggers workflows for any service)
- **Rationale:** Event infrastructure is shared, service context passed as parameters

### ArgoCD Applications (GitOps)
**Pattern:** `<service>-<env>` (generated by ApplicationSet)
- **Application:** `nginx-dev`, `nginx-staging`, `nginx-prod`
- **Namespace:** Matches environment (dev, staging, prod)
- **Generated:** Automatically by ApplicationSet matrix generator

## Anti-Patterns to Avoid
- Don't hardcode namespaces (use `.Release.Namespace`) - ArgoCD manages namespace assignments
- Avoid enabling multiple routing options (ingress/httpRoute) simultaneously
- Don't set opinionated resource limits in default values - use environment-specific values in `services/*/values-<env>.yaml`
- Never skip the 63-character truncation for generated names
- Don't use `{{ . }}` in range blocks without capturing to variable first
- Don't mix Deployment and Rollout - use conditional rendering based on `.Values.cw-rollout.enabled`
- Avoid environment-specific logic in chart templates - externalize to `services/` values files
- Don't commit secrets to Git - use Sealed Secrets or External Secrets Operator
- Don't bypass the naming standard - always set `environment`, `flavor` (optional), `region` in environment-specific values
- Avoid using `fullnameOverride` unless absolutely necessary - it breaks naming consistency
- Don't modify `cw-service/` chart directly for service-specific needs - use values overrides in `services/<name>/`
- Never update Git URLs in multiple places - centralize in `cw-argo-bootstrap/` manifests only
- **Kargo:** Don't use simple names like `dev`, `staging`, `prod` - use full naming: `<service>-<env>-<region>`
- **Workflows:** Don't hardcode service names in WorkflowTemplates - use parameters for reusability
- **Kyverno:** Don't start with Enforce mode - use Audit first, monitor PolicyReports, then enforce after testing

## File Naming Conventions
- Templates: lowercase with hyphens (`http-route.yaml` not `HTTPRoute.yaml`)
- Values: camelCase keys (`httpRoute` not `http_route`)
- Helpers: Prefix all template names with chart name (`cw-service.fullname`)
