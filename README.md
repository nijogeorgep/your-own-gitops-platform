# GitOps Platform

A production-ready, scalable GitOps platform for Kubernetes using ArgoCD, Argo Rollouts, Argo Events/Workflows, Kargo, and Kyverno for automated progressive delivery with policy enforcement at scale.

## 🎯 Project Overview

This platform provides **automated continuous delivery** for 1000+ microservices with:

- **GitOps-driven deployments** via ArgoCD ApplicationSet auto-discovery
- **Progressive delivery** with Argo Rollouts (canary/blue-green strategies)
- **Multi-provider analysis** (Prometheus, Datadog, New Relic, webhooks)
- **Automated promotions** across environments (dev → staging → prod) via Kargo
- **CI/CD automation** with Argo Events and Workflows
- **Service mesh integration** with Istio for traffic management and mTLS
- **Policy enforcement** with Kyverno for admission control and compliance
- **Scalable architecture** supporting 1000+ services without performance degradation

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Git Repository                          │
│  services/                                                  │
│  ├── nginx/                                                 │
│  │   ├── base-values.yaml                                   │
│  │   ├── values-dev.yaml                                    │
│  │   ├── values-staging.yaml                                │
│  │   └── values-prod.yaml                                   │
│  └── <1000+ services>                                       │
└──────────────┬──────────────────────────────────────────────┘
               │
               ├──► ArgoCD ApplicationSet (auto-discovery)
               │    └──► Generates: service-dev, service-staging, service-prod
               │
               ├──► Argo Events (GitHub webhooks)
               │    └──► Triggers: Argo Workflows (build → push → update Git)
               │
               └──► Kargo (progressive promotions)
                    └──► Warehouse → dev → staging → prod
                                          
┌─────────────────────────────────────────────────────────────┐
│                   Kubernetes Cluster                        │
│                                                             │
│  ┌───────────────┐  ┌───────────────┐  ┌────────────────┐   │
│  │   ArgoCD      │  │ Argo Rollouts │  │     Kargo      │   │
│  │  (GitOps)     │  │  (Canary/BG)  │  │  (Promotion)   │   │
│  └───────────────┘  └───────────────┘  └────────────────┘   │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │           Istio Service Mesh + Kyverno Policies       │  │
│  │  (Traffic routing, mTLS, Admission control)           │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                      │
│  │ Service │  │ Service │  │ Service │  ... (1000+ pods)    │
│  │   dev   │  │ staging │  │  prod   │                      │
│  └─────────┘  └─────────┘  └─────────┘                      │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Key Features

### 1. **Auto-Discovery Service Deployment**
- Drop a new service directory in `services/` → ArgoCD auto-creates 3 Applications (dev/staging/prod)
- No manual Application creation needed
- Scales to 1000+ services with ApplicationSet sharding

### 2. **Progressive Delivery**
- **Argo Rollouts**: Canary deployments with automated analysis
- **Multi-provider metrics**: Prometheus, Datadog, New Relic, custom webhooks
- **Automated rollback**: Metrics-driven failure detection
- **Blue-Green deployments**: Instant switch with preview environments

### 3. **Automated CI/CD Pipeline**
```
Git Push → GitHub Webhook → Argo Events → Argo Workflows
  ↓
Build Image (Kaniko) → Push to Registry → Update values-dev.yaml
  ↓
Git Commit → ArgoCD Sync → Deploy to Kubernetes
```

### 4. **Multi-Environment Promotion**
```
Kargo Warehouse (image registry) → Auto-promote to dev
  ↓
Staging (auto-promote after validation)
  ↓
Production (manual approval required)
```

### 5. **Service Mesh Integration**
- **Istio VirtualService**: Advanced traffic routing, retries, timeouts
- **Circuit breaking**: Connection pooling, outlier detection
- **mTLS**: Automatic service-to-service encryption
- **Gateway API**: Modern HTTPRoute for ingress

## 📋 Prerequisites

### Required Tools
- **Kubernetes cluster** (v1.28+)
  - Docker Desktop (local dev)
  - Kind/Minikube (local dev)
  - EKS/GKE/AKS (production)
- **kubectl** (v1.28+)
- **Helm** (v3.14+)
- **PowerShell** (v7.0+) or **Bash**
- **Git**

### Cluster Requirements
- **Minimum:** 4 CPU cores, 8GB RAM (for local testing)
- **Recommended:** 8 CPU cores, 16GB RAM (for full platform)
- **Production:** 16+ CPU cores, 32GB+ RAM (for 1000+ services)

### External Services (Optional)
- **Container Registry**: Docker Hub, ECR, GCR, ACR, or private registry
- **Git Provider**: GitHub, GitLab, Bitbucket (for webhooks)
- **Observability**: Prometheus, Datadog, New Relic (for analysis templates)

## 🛠️ Installation

### Step 1: Clone Repository

```powershell
git clone https://github.com/cloudwalkersinc/cw-gitops-platform.git
cd cw-gitops-platform
```

### Step 2: Install Platform Components

The platform provides automated installation scripts for all components.

#### Option A: Install All Components at Once (Recommended)

```powershell
cd cw-tools

# Install everything with one command
.\install-all.ps1 -Email your-email@example.com

# This installs:
# - cert-manager (TLS automation)
# - Istio (service mesh)
# - ArgoCD (GitOps controller)
# - Argo Rollouts (progressive delivery)
# - Argo Events (event automation)
# - Argo Workflows (CI/CD pipelines)
# - Kargo (promotion orchestration)
# - Kyverno (policy enforcement)
# - Headlamp (Kubernetes UI)
```

#### Option B: Install Components Individually

```powershell
cd cw-tools

# 1. TLS Certificate Management
.\install-cert-manager.ps1 -Email your-email@example.com

# 2. Service Mesh
.\install-istio.ps1

# 3. GitOps Controller
.\install-argocd.ps1

# 4. Progressive Delivery
.\install-argo-rollouts.ps1

# 5. Event Automation
.\install-argo-events.ps1

# 6. CI/CD Workflows (optional)
# .\install-argo-workflows.ps1

# 7. Promotion Orchestration
.\install-kargo.ps1

# 8. Policy Enforcement
.\install-kyverno.ps1

# 9. Kubernetes UI (optional)
.\install-headlamp.ps1
```

**Installation time:** 5-10 minutes (depending on cluster speed)

### Step 3: Configure Platform Gateway

Expose all platform UIs through a single Istio Gateway.

```powershell
cd cw-tools\cw-gateway

# Apply Gateway and VirtualService configurations
.\apply.ps1

# For local development (port-forward to localhost:8080)
.\start-gateway.ps1

# Access UIs at:
# - ArgoCD:        http://localhost:8080/argocd
# - Argo Rollouts: http://localhost:8080/rollouts
# - Kargo:         http://localhost:8080/kargo
# - Headlamp:      http://localhost:8080/headlamp
```

### Step 4: Deploy Kyverno Policies

Deploy admission control policies (starts in Audit mode for safety).

```powershell
cd cw-policies

# Deploy all policies in Audit mode (recommended)
.\deploy.ps1

# Monitor policy violations
kubectl get policyreports -A

# After testing, switch to Enforce mode
.\deploy.ps1 -Mode Enforce
```

### Step 5: Configure ArgoCD Path Prefix

```powershell
# Configure ArgoCD for sub-path routing
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{
  "data": {
    "server.basehref": "/argocd",
    "server.rootpath": "/argocd"
  }
}'

# Restart ArgoCD server
kubectl rollout restart deployment argocd-server -n argocd

# Get initial admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

### Step 6: Update Git Repository URLs

Update the Git repository URLs in configuration files:

```powershell
# Edit these files with your Git repository URL:
# 1. cw-argo-bootstrap/applicationset-services.yaml
# 2. cw-argo-bootstrap/app-of-apps.yaml
# 3. cw-argo-bootstrap/application-policies.yaml
# 4. cw-events/eventsource-github.yaml (if using events)

# Example:
# OLD: repoURL: https://github.com/YOUR_ORG/cw-gitops-platform.git
# NEW: repoURL: https://github.com/mycompany/my-gitops-platform.git
```

### Step 7: Bootstrap ArgoCD ApplicationSet

Deploy the ApplicationSet that auto-discovers services:

```powershell
cd cw-argo-bootstrap

# Deploy the root Application (App of Apps pattern)
kubectl apply -f app-of-apps.yaml

# Deploy Kyverno policies via ArgoCD
kubectl apply -f application-policies.yaml

# Verify ApplicationSet created
kubectl get applicationset -n argocd

# View auto-generated Applications
kubectl get applications -n argocd
```

### Step 8: Deploy Your First Service

```powershell
# Create a new service directory
mkdir services\myapp
cd services\myapp

# Copy template files
# (See services/SERVICE-TEMPLATE.md for complete guide)

# Create base-values.yaml
cat > base-values.yaml @"
replicaCount: 2
image:
  repository: myregistry/myapp
  pullPolicy: IfNotPresent
service:
  port: 80
  targetPort: 8080
"@

# Create values-dev.yaml
cat > values-dev.yaml @"
environment: dev
region: us-east-1
replicaCount: 1
image:
  tag: "latest"
resources:
  limits:
    cpu: 100m
    memory: 128Mi
"@

# Create values-staging.yaml and values-prod.yaml similarly

# Commit and push
git add .
git commit -m "Add myapp service"
git push origin main

# ArgoCD will auto-create: myapp-dev, myapp-staging, myapp-prod
# Check ArgoCD UI: http://localhost:8080/argocd
```

### Step 8: Enable Progressive Delivery (Optional)

Add Argo Rollouts for canary deployments:

```powershell
# Edit services/myapp/values-prod.yaml
cat >> values-prod.yaml @"
cw-rollout:
  enabled: true
  rollout:
    strategy: canary
    canary:
      steps:
        - setWeight: 10
        - pause: {duration: 5m}
        - setWeight: 50
        - pause: {duration: 10m}
  
  analysisTemplates:
    prometheus:
      enabled: true
      address: http://prometheus.monitoring:9090
      queries:
        successRate:
          enabled: true
          threshold: 0.95
"@

# Commit changes
git add values-prod.yaml
git commit -m "Enable progressive delivery for myapp"
git push origin main
```

### Step 9: Setup Kargo Promotions (Optional)

Automate environment promotions:

```powershell
cd cw-kargo

# Generate Kargo resources for all services
.\generate-kargo-resources.ps1 `
    -ImageRepository myregistry.io `
    -GitRepoURL https://github.com/mycompany/my-gitops-platform.git `
    -Region us-east-1

# Review generated resources
Get-ChildItem projects -Recurse -Filter *.yaml

# Deploy to cluster
.\deploy.ps1

# Verify Kargo resources
kubectl get projects --all-namespaces
kubectl get warehouses,stages -n kargo-myapp
```

### Step 10: Setup CI/CD Pipeline (Optional)

Automate builds and deployments:

```powershell
cd cw-events

# Deploy EventSources (GitHub webhooks)
kubectl apply -f eventsource-github.yaml

# Deploy Sensors (workflow triggers)
kubectl apply -f sensor-image-update.yaml

# Configure GitHub webhook:
# URL: http://your-cluster/webhook
# Content-Type: application/json
# Events: push, pull_request
```

## 📚 Documentation

- **[NAMING-STANDARDS.md](NAMING-STANDARDS.md)** - Naming conventions for all platform components
- **[cw-service/README.md](cw-service/README.md)** - Helm chart documentation
- **[cw-service/charts/cw-rollout/README.md](cw-service/charts/cw-rollout/README.md)** - Progressive delivery guide
- **[cw-argo-bootstrap/SCALABILITY.md](cw-argo-bootstrap/SCALABILITY.md)** - Scaling to 1000+ services
- **[services/SERVICE-TEMPLATE.md](services/SERVICE-TEMPLATE.md)** - Service creation guide
- **[.github/copilot-instructions.md](.github/copilot-instructions.md)** - AI agent development guide

## 🔧 Common Operations

### View Platform Status

```powershell
# Check all ArgoCD Applications
kubectl get applications -n argocd

# Check Argo Rollouts
kubectl get rollouts --all-namespaces

# Check Kargo promotions
kubectl get stages,warehouses --all-namespaces

# View platform pods
kubectl get pods -n argocd
kubectl get pods -n argo-rollouts
kubectl get pods -n kargo
kubectl get pods -n istio-system
```

### Deploy a New Service

```bash
# 1. Create service directory
mkdir services/new-service

# 2. Add values files (see SERVICE-TEMPLATE.md)
# - base-values.yaml
# - values-dev.yaml
# - values-staging.yaml
# - values-prod.yaml

# 3. Commit and push
git add services/new-service
git commit -m "Add new-service"
git push origin main

# 4. ApplicationSet auto-creates 3 Applications
# 5. Check ArgoCD UI for sync status
```

### Trigger a Canary Rollout

```bash
# Update image tag in values-prod.yaml
sed -i 's/tag: "v1.0.0"/tag: "v1.1.0"/' services/myapp/values-prod.yaml

# Commit and push
git commit -am "Update myapp to v1.1.0"
git push origin main

# Monitor rollout progress
kubectl argo rollouts get rollout myapp-prod-us-east-1 -n prod -w

# Promote manually (if auto-promotion disabled)
kubectl argo rollouts promote myapp-prod-us-east-1 -n prod
```

### Promote Through Environments

```bash
# With Kargo (automated):
# 1. New image detected → Warehouse
# 2. Auto-promote to dev
# 3. Auto-promote to staging (after validation)
# 4. Manual approval for prod

# Manual promotion:
kubectl annotate stage myapp-prod-us-east-1 -n kargo-myapp \
  kargo.akuity.io/promote=true
```

### Rollback a Deployment

```bash
# Rollback Argo Rollout
kubectl argo rollouts abort myapp-prod-us-east-1 -n prod
kubectl argo rollouts undo myapp-prod-us-east-1 -n prod

# Rollback via Git (revert commit)
git revert HEAD
git push origin main
# ArgoCD syncs automatically
```

## 🎓 Examples

### Example 1: Simple Web Service

```yaml
# services/web-frontend/values-prod.yaml
environment: prod
region: us-east-1

replicaCount: 3

image:
  repository: myregistry/web-frontend
  tag: "v2.0.0"

service:
  port: 80
  targetPort: 3000

httpRoute:
  enabled: true
  parentRefs:
    - name: gateway
      namespace: istio-system
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /

resources:
  limits:
    cpu: 500m
    memory: 512Mi
```

### Example 2: API with Canary Rollout

```yaml
# services/api-gateway/values-prod.yaml
environment: prod
region: us-east-1

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
          threshold: 0.95
```

### Example 3: Service with Istio mTLS

```yaml
# services/payment-service/values-prod.yaml
environment: prod
region: us-east-1

cw-istio:
  enabled: true
  
  virtualService:
    enabled: true
    hosts:
      - payment.example.com
    gateways:
      - istio-system/platform-gateway
  
  destinationRule:
    enabled: true
    trafficPolicy:
      connectionPool:
        tcp:
          maxConnections: 100
      outlierDetection:
        consecutiveErrors: 5
  
  peerAuthentication:
    enabled: true
    mtlsMode: STRICT
```

## 🔍 Troubleshooting

### ArgoCD Application Not Syncing

```bash
# Check Application status
kubectl describe application myapp-dev -n argocd

# Force refresh
kubectl patch application myapp-dev -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Check ApplicationSet
kubectl describe applicationset services -n argocd
```

### Rollout Stuck in Progressing

```bash
# Check rollout status
kubectl argo rollouts get rollout myapp-prod-us-east-1 -n prod

# Check analysis run
kubectl get analysisrun -n prod
kubectl describe analysisrun <name> -n prod

# Abort and rollback
kubectl argo rollouts abort myapp-prod-us-east-1 -n prod
```

### Kargo Promotion Not Working

```bash
# Check Warehouse
kubectl describe warehouse myapp-warehouse -n kargo-myapp

# Check Stage
kubectl describe stage myapp-dev-us-east-1 -n kargo-myapp

# View promotion logs
kubectl logs -n kargo -l app.kubernetes.io/name=kargo
```

## 📊 Scalability

The platform is designed to scale to **1000+ services**:

- **ArgoCD ApplicationSet**: Supports 3000 Applications (1000 services × 3 environments)
- **Sharding**: Enable controller sharding for 500+ services (see [SCALABILITY.md](cw-argo-bootstrap/SCALABILITY.md))
- **Kargo**: Isolated namespaces per service (1 project per service)
- **Argo Rollouts**: Service-level opt-in, no coordination needed
- **Performance**: 5-minute Git polling, 3-5 controller replicas for optimal performance

Enable sharding for large deployments:

```powershell
cd cw-argo-bootstrap
.\enable-sharding.ps1 -Replicas 3 -ApplyChanges
```

## 🤝 Contributing

1. Create a feature branch
2. Make changes following platform conventions (see [NAMING-STANDARDS.md](NAMING-STANDARDS.md))
3. Test locally using `cw-scripts/helm/` testing tools
4. Submit pull request

## 📝 License

[Add your license here]

## 🙏 Acknowledgments

Built with:
- [ArgoCD](https://argo-cd.readthedocs.io/) - GitOps continuous delivery
- [Argo Rollouts](https://argo-rollouts.readthedocs.io/) - Progressive delivery
- [Argo Events](https://argoproj.github.io/argo-events/) - Event-driven workflows
- [Argo Workflows](https://argoproj.github.io/argo-workflows/) - Container-native workflows
- [Kargo](https://kargo.io/) - Promotion orchestration
- [Istio](https://istio.io/) - Service mesh
- [Helm](https://helm.sh/) - Kubernetes package manager
- [cert-manager](https://cert-manager.io/) - TLS automation

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/cloudwalkersinc/cw-gitops-platform/issues)
- **Documentation**: See `docs/` directory
- **AI Agent Guide**: [.github/copilot-instructions.md](.github/copilot-instructions.md)

---

**Status**: Production-ready | **Version**: 1.0.0 | **Last Updated**: January 2026
