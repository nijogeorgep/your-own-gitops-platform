# Platform Installation Tools

PowerShell scripts for installing the complete GitOps platform stack on any Kubernetes cluster.

## Version Management

Tool versions are centrally managed in [versions.psd1](versions.psd1). Update versions there to upgrade components across all scripts.

**Current versions:**
- cert-manager: v1.19.2
- Istio: 1.28.3
- ArgoCD: 9.3.4 (Helm chart)
- Argo Rollouts: 2.40.5 (Helm chart)
- Argo Events: 2.4.19 (Helm chart)
- Kargo: 1.8.6 (Helm chart)
- Headlamp: 0.28.1 (Helm chart)

To override versions for individual installations, pass the `-Version` parameter:
```powershell
.\install-istio.ps1 -IstioVersion "1.21.0"
.\install-kargo.ps1 -Version "0.7.0"
```

## Quick Start

### Install Complete Stack
```powershell
.\install-all.ps1 -Email admin@example.com
```

### Install Individual Components
```powershell
# Install cert-manager with Let's Encrypt
.\install-cert-manager.ps1 -Email admin@example.com

# Install Istio service mesh
.\install-istio.ps1

# Install ArgoCD
.\install-argocd.ps1

# Install Argo Rollouts
.\install-argo-rollouts.ps1

# Install Argo Events
.\install-argo-events.ps1

# Install Kargo
.\install-kargo.ps1

# Install Headlamp
.\install-headlamp.ps1
```

## Prerequisites

- **Kubernetes Cluster** - Any Kubernetes 1.24+ cluster:
  - minikube
  - kind (Kubernetes in Docker)
  - k3s/k3d
  - Docker Desktop
  - Cloud providers (EKS, GKE, AKS)

- **kubectl** - Configured with cluster access
  ```powershell
  kubectl version
  kubectl cluster-info
  ```

- **PowerShell 7+** - For cross-platform support
  ```powershell
  $PSVersionTable.PSVersion
  ```

- **Helm 3** (optional, for some components)
  ```powershell
  helm version
  ```

## Components

### 1. cert-manager
**Purpose:** Automated TLS certificate management with Let's Encrypt

**Installation:**
```powershell
.\install-cert-manager.ps1 -Email admin@example.com
```

**Features:**
- Automatic certificate issuance and renewal
- Let's Encrypt staging and production issuers
- Supports HTTP-01 and DNS-01 challenges
- Certificate lifecycle management

**Post-Install:**
```powershell
# Check ClusterIssuers
kubectl get clusterissuers

# View certificates
kubectl get certificates --all-namespaces
```

### 2. Istio
**Purpose:** Service mesh for traffic management, security, and observability

**Installation:**
```powershell
.\install-istio.ps1 -Profile default
```

**Profiles:**
- `minimal` - Lightweight, no ingress gateway
- `default` - Production ready with ingress (recommended)
- `demo` - Includes observability tools
- `ambient` - Ambient mesh mode

**Features:**
- Traffic management (routing, retries, circuit breaking)
- mTLS encryption between services
- Ingress gateway for external traffic
- Sidecar injection for service mesh

**Post-Install:**
```powershell
# Check Istio status
istioctl version
istioctl proxy-status

# Enable sidecar injection
kubectl label namespace <namespace> istio-injection=enabled
```

### 3. ArgoCD
**Purpose:** Declarative GitOps continuous delivery

**Installation:**
```powershell
.\install-argocd.ps1 -ServiceType LoadBalancer
```

**Features:**
- Git repository as source of truth
- Automated deployment synchronization
- Multi-cluster management
- Web UI and CLI
- SSO integration support

**Post-Install:**
```powershell
# Get admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# Port forward UI (if not using LoadBalancer)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access: https://localhost:8080
# Username: admin
```

### 4. Argo Rollouts
**Purpose:** Progressive delivery with canary and blue-green deployments

**Installation:**
```powershell
.\install-argo-rollouts.ps1
```

**Features:**
- Canary deployments with traffic shifting
- Blue-green deployments
- Automated rollback on failure
- Integration with Istio for traffic control
- Prometheus metrics for analysis

**Post-Install:**
```powershell
# Install kubectl plugin
# Download from: https://github.com/argoproj/argo-rollouts/releases

# Access dashboard
kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100
# Browse: http://localhost:3100

# View rollouts
kubectl argo rollouts list
```

### 5. Argo Events
**Purpose:** Event-driven workflow automation

**Installation:**
```powershell
.\install-argo-events.ps1
```

**Features:**
- Event sources (webhook, git, S3, SNS, Kafka, etc.)
- Sensors to trigger actions
- Integration with Argo Workflows
- Custom triggers (K8s resources, HTTP, NATS)

**Event Sources:**
- Webhooks
- Git events (push, PR)
- Calendar/cron
- Resource changes
- Cloud events (AWS, GCP, Azure)
- Message queues (Kafka, NATS, Redis)

**Post-Install:**
```powershell
# Check EventBus
kubectl get eventbus -n argo-events

# View event sources
kubectl get eventsources -n argo-events

# View sensors
kubectl get sensors -n argo-events
```

### 6. Kargo
**Purpose:** Advanced promotion workflows for multi-stage GitOps

**Installation:**
```powershell
.\install-kargo.ps1
```

**Dependencies:**
- Requires cert-manager (installs automatically if missing)

**Features:**
- Multi-stage promotions (dev → staging → prod)
- Git-based artifact promotion
- ArgoCD integration
- Approval gates
- Automated and manual promotions

**Post-Install:**
```powershell
# Port forward UI
kubectl port-forward svc/kargo-api -n kargo 8080:80
# Browse: http://localhost:8080

# Check CRDs
kubectl get crds | grep kargo

# View projects
kubectl get projects -n kargo

# View stages
kubectl get stages -n kargo
```

### 7. Headlamp
**Purpose:** User-friendly Kubernetes web UI for cluster management

**Installation:**
```powershell
.\install-headlamp.ps1
```

**Features:**
- Modern, intuitive web interface
- Real-time cluster monitoring
- Resource management (pods, services, deployments, etc.)
- YAML editor with validation
- Pod logs and shell access
- RBAC-aware (shows only authorized resources)
- Multi-cluster support
- Plugin system for extensibility

**Configuration Options:**
```powershell
# Default installation (ClusterIP)
.\install-headlamp.ps1

# LoadBalancer for external access
.\install-headlamp.ps1 -ServiceType LoadBalancer

# High availability with multiple replicas
.\install-headlamp.ps1 -Replicas 2

# Custom namespace
.\install-headlamp.ps1 -Namespace kube-system
```

**Post-Install:**
```powershell
# Port forward to access locally
kubectl port-forward -n headlamp service/headlamp 8080:80
# Browse: http://localhost:8080

# Create service account token for authentication
kubectl create token headlamp --namespace headlamp

# View Headlamp logs
kubectl logs -n headlamp -l app.kubernetes.io/name=headlamp
```

**Access Methods:**
- **ClusterIP (default):** Port-forward for local access
- **LoadBalancer:** External IP (cloud providers)
- **NodePort:** Access via node IP and port
- **Ingress:** Configure ingress controller separately

## Installation Order

The `install-all.ps1` script installs components in the optimal order:

1. **cert-manager** - Required by Kargo, used for TLS
2. **Istio** - Service mesh foundation
3. **ArgoCD** - GitOps engine
4. **Argo Rollouts** - Progressive delivery
5. **Argo Events** - Event automation
6. **Kargo** - Promotion workflows
7. **Headlamp** - Web UI (optional, no dependencies)

## Common Workflows

### Local Development Cluster Setup
```powershell
# Create kind cluster
kind create cluster --name gitops-platform

# Install complete stack
.\install-all.ps1 -Email dev@example.com

# Deploy sample application
cd ..\cw-scripts\helm
.\install.ps1
```

### Production Cluster Setup
```powershell
# Verify cluster access
kubectl cluster-info

# Install with production email for Let's Encrypt
.\install-all.ps1 -Email ops@production.com

# Verify all components
kubectl get pods --all-namespaces | Select-String "istio|argocd|argo-|kargo|cert-manager"
```

### Selective Installation
```powershell
# Install only ArgoCD and Argo Rollouts
.\install-all.ps1 -Email admin@example.com -SkipIstio -SkipEvents -SkipKargo
```

## Troubleshooting

### Check Installation Status
```powershell
# All platform pods
kubectl get pods --all-namespaces | Select-String "istio|argocd|argo-|kargo|cert-manager|headlamp"

# Specific component
kubectl get pods -n argocd
kubectl get pods -n istio-system
kubectl get pods -n headlamp
```

### View Logs
```powershell
# ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Istio
kubectl logs -n istio-system -l app=istiod

# Argo Rollouts
kubectl logs -n argo-rollouts -l app.kubernetes.io/name=argo-rollouts
```

### Common Issues

**cert-manager webhook not ready:**
```powershell
kubectl get validatingwebhookconfigurations
kubectl delete validatingwebhookconfiguration cert-manager-webhook
.\install-cert-manager.ps1
```

**Istio installation fails:**
```powershell
istioctl x precheck
istioctl verify-install
```

**ArgoCD pods not ready:**
```powershell
kubectl describe pod -n argocd
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

## Uninstallation

### Remove Individual Components
```powershell
# cert-manager
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.1/cert-manager.yaml

# Istio
istioctl uninstall --purge -y
kubectl delete namespace istio-system

# ArgoCD
kubectl delete namespace argocd

# Argo Rollouts
kubectl delete namespace argo-rollouts

# Argo Events
kubectl delete namespace argo-events

# Kargo
kubectl delete namespace kargo

# Headlamp
kubectl delete namespace headlamp
```

### Clean Up CRDs
```powershell
kubectl get crds | Select-String "istio|argoproj|kargo|cert-manager" | ForEach-Object {
    kubectl delete crd $_.Line.Split()[0]
}
```

## Version Matrix

| Component | Default Version | Tested Versions |
|-----------|----------------|-----------------|
| cert-manager | v1.14.1 | v1.13.x, v1.14.x |
| Istio | 1.20.2 | 1.19.x, 1.20.x |
| ArgoCD | stable (v2.9+) | v2.8.x, v2.9.x |
| Argo Rollouts | v1.6.4 | v1.5.x, v1.6.x |
| Argo Events | v1.9.0 | v1.8.x, v1.9.x |
| Kargo | v0.6.0 | v0.5.x, v0.6.x |

## Resources

- **cert-manager:** https://cert-manager.io/
- **Istio:** https://istio.io/
- **ArgoCD:** https://argo-cd.readthedocs.io/
- **Headlamp:** https://headlamp.dev/
- **Argo Rollouts:** https://argoproj.github.io/argo-rollouts/
- **Argo Events:** https://argoproj.github.io/argo-events/
- **Kargo:** https://github.com/akuity/kargo

## Support

For issues specific to this platform:
1. Check script output for errors
2. Verify prerequisites (kubectl, cluster access)
3. Review component logs: `kubectl logs -n <namespace>`
4. Check official documentation for each tool
