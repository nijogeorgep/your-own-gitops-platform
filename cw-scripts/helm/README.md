# Helm Deployment Scripts

Scripts for deploying and managing applications using the `cw-service` Helm chart.

## Quick Start

### Install Nginx (Development)
```powershell
.\install.ps1
```

### Install Nginx (Production)
```powershell
.\install.ps1 -ReleaseName nginx-prod -ValuesFile nginx-prod-values.yaml -Namespace production
```

### Preview Changes (Dry Run)
```powershell
.\install.ps1 -DryRun
```

### Render Templates Locally
```powershell
.\template.ps1 -OutputFile nginx-manifests.yaml
```

## Scripts

### install.ps1
Installs the cw-service chart with specified configuration.

**Parameters:**
- `ReleaseName` - Helm release name (default: nginx)
- `ValuesFile` - Values file to use (default: nginx-dev-values.yaml)
- `Namespace` - Target namespace (default: default)
- `DryRun` - Validate without installing

**Examples:**
```powershell
# Basic install
.\install.ps1

# Custom release with production values
.\install.ps1 -ReleaseName myapp -ValuesFile nginx-prod-values.yaml -Namespace prod

# Validate configuration
.\install.ps1 -DryRun
```

### upgrade.ps1
Upgrades an existing release with new values or chart version.

**Parameters:**
- `ReleaseName` - Helm release name (default: nginx)
- `ValuesFile` - Values file to use (default: nginx-dev-values.yaml)
- `Namespace` - Target namespace (default: default)
- `Install` - Install if release doesn't exist
- `DryRun` - Preview changes without applying

**Examples:**
```powershell
# Upgrade existing release
.\upgrade.ps1

# Upgrade or install
.\upgrade.ps1 -Install

# Preview upgrade changes
.\upgrade.ps1 -DryRun
```

### template.ps1
Renders chart templates to YAML without deploying.

**Parameters:**
- `ReleaseName` - Helm release name (default: nginx)
- `ValuesFile` - Values file to use (default: nginx-dev-values.yaml)
- `OutputFile` - Save to file (optional, default: stdout)
- `Debug` - Show detailed rendering info

**Examples:**
```powershell
# Render to console
.\template.ps1

# Save to file
.\template.ps1 -OutputFile manifests.yaml

# Debug template issues
.\template.ps1 -Debug
```

### uninstall.ps1
Removes a Helm release and its resources.

**Parameters:**
- `ReleaseName` - Helm release name (default: nginx)
- `Namespace` - Target namespace (default: default)
- `KeepHistory` - Preserve history for rollback

**Examples:**
```powershell
# Uninstall release
.\uninstall.ps1

# Uninstall with confirmation
.\uninstall.ps1 -ReleaseName nginx-prod -Namespace production

# Keep history for rollback
.\uninstall.ps1 -KeepHistory
```

## Values Files

### nginx-dev-values.yaml
Development environment configuration:
- 2 replicas
- Basic resource limits (100m CPU, 128Mi RAM)
- No autoscaling
- Security contexts enabled
- Istio disabled

### nginx-prod-values.yaml
Production environment configuration:
- 3 replicas minimum
- Autoscaling (3-10 pods)
- Higher resource limits (250m CPU, 256Mi RAM)
- Pod anti-affinity for HA
- Istio enabled with VirtualService and DestinationRule
- mTLS STRICT mode
- Connection pooling and circuit breaking

## Platform Naming Convention

Resources are named following the pattern:
```
<app-name>-<environment>-<flavor>-<region>
```

**Examples:**
- `nginx-dev-us-east-1` (dev environment, no flavor)
- `nginx-prod-web-us-east-1` (prod environment with flavor)

**Configuration:**
```yaml
nameOverride: "nginx"
environment: "prod"
flavor: "web"      # Optional
region: "us-east-1"
```

## Common Workflows

### Deploy New Application
```powershell
# 1. Create values file (copy from nginx-dev-values.yaml)
# 2. Customize settings
# 3. Install
.\install.ps1 -ReleaseName myapp -ValuesFile myapp-values.yaml
```

### Update Configuration
```powershell
# 1. Modify values file
# 2. Upgrade
.\upgrade.ps1 -ReleaseName myapp -ValuesFile myapp-values.yaml
```

### Validate Before Deploy
```powershell
# Render and review
.\template.ps1 -ValuesFile myapp-values.yaml -OutputFile manifests.yaml

# Review manifests
code manifests.yaml

# Deploy
.\install.ps1 -ReleaseName myapp -ValuesFile myapp-values.yaml
```

### Troubleshooting

**Check release status:**
```powershell
helm status nginx -n default
```

**View rendered templates:**
```powershell
.\template.ps1 -Debug
```

**Check pod logs:**
```powershell
kubectl logs -n default -l app.kubernetes.io/instance=nginx
```

**View resource limits:**
```powershell
kubectl describe deployment -n default -l app.kubernetes.io/instance=nginx
```

## Prerequisites

- Helm 3.x installed
- kubectl configured with cluster access
- PowerShell 7+ (for cross-platform support)
- Kubernetes cluster (minikube, kind, k3s, or cloud)

## GitOps Integration

These scripts are useful for:
1. **Local testing** before committing to ArgoCD
2. **CI/CD pipelines** for template validation
3. **Manual deployments** in non-GitOps environments
4. **Debugging** chart issues

For production GitOps workflows, use ArgoCD Applications in `cw-argo/` directory.
