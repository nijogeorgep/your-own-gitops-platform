# Helm Namespace Management Guide

## Problem
By default, `helm install` deploys to the `default` namespace unless explicitly specified.

## Solutions

### ✅ Option 1: Pass Namespace Parameter (Recommended)
Always specify the namespace when running install scripts:

```powershell
# Install to dev namespace
.\install.ps1 -ReleaseName nginx -ValuesFile nginx-dev-values.yaml -Namespace dev

# Install to production namespace
.\install.ps1 -ReleaseName nginx-prod -ValuesFile nginx-prod-values.yaml -Namespace prod
```

### ✅ Option 2: Change Script Default
Edit `install.ps1` to use environment-based namespace:

```powershell
# Before (line 32)
[string]$Namespace = "default"

# After - derive from values file or environment
[string]$Namespace = ""  # Will be computed from environment
```

### ✅ Option 3: Use Values-Based Namespace
The chart can auto-derive namespace from the `environment` value:

```powershell
# In install.ps1, after loading values:
if (-not $Namespace) {
    # Extract environment from values file
    $envValue = (Select-String -Path $ValuesPath -Pattern "^environment:" | ForEach-Object { $_.Line.Split(":")[1].Trim() })
    $Namespace = $envValue
}
```

## Best Practice for GitOps Platform

Since you're using environment-based deployments (dev/staging/prod), align namespaces with environments:

**File: nginx-dev-values.yaml**
```yaml
environment: "dev"  # This should match your namespace: dev
```

**Installation:**
```powershell
# Manually specify namespace to match environment
.\install.ps1 -ReleaseName nginx-dev -ValuesFile nginx-dev-values.yaml -Namespace dev
```

Or update the script to auto-detect:
```powershell
# Auto-detect namespace from environment value
if ([string]::IsNullOrEmpty($Namespace)) {
    $Namespace = (Select-String -Path $ValuesPath -Pattern "^environment:\s*[`"']?(\w+)" | 
                  ForEach-Object { $_.Matches.Groups[1].Value })
    if ([string]::IsNullOrEmpty($Namespace)) {
        $Namespace = "default"
    }
}
```

## Verify Namespace Isolation

After installation:
```powershell
# Check all resources in namespace
kubectl get all -n dev

# Verify no resources in default namespace
kubectl get all -n default
```

## ArgoCD ApplicationSet Pattern

For GitOps deployments, the ApplicationSet already handles this correctly:

```yaml
# cw-argo-bootstrap/applicationset-services.yaml
spec:
  destination:
    namespace: "{{ env }}"  # Auto-creates dev, staging, prod namespaces
```

Resources will be deployed to:
- `dev` namespace for dev environment
- `staging` namespace for staging environment  
- `prod` namespace for production environment
