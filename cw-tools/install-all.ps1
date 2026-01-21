#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install complete GitOps platform stack

.DESCRIPTION
    Installs all platform tools in the correct order with dependencies.
    Includes: cert-manager, Istio, ArgoCD, Argo Rollouts, Argo Events, Kargo

.PARAMETER Email
    Email for Let's Encrypt registration

.PARAMETER SkipIstio
    Skip Istio installation

.PARAMETER SkipArgoCD
    Skip ArgoCD installation

.PARAMETER SkipRollouts
    Skip Argo Rollouts installation

.PARAMETER SkipEvents
    Skip Argo Events installation

.PARAMETER SkipKargo
    Skip Kargo installation

.PARAMETER SkipDashboard
    Skip Kubernetes Dashboard installation

.PARAMETER SkipCertManager
    Skip cert-manager installation

.EXAMPLE
    .\install-all.ps1 -Email admin@example.com
    # Install complete stack

.EXAMPLE
    .\install-all.ps1 -Email admin@example.com -SkipIstio
    # Install without Istio

.EXAMPLE
    .\install-all.ps1 -Email admin@example.com -SkipDashboard
    # Install without Kubernetes Dashboard UI
#>

param(
    [string]$Email = "",
    [switch]$SkipIstio,
    [switch]$SkipDashboard,
    [switch]$SkipArgoCD,
    [switch]$SkipRollouts,
    [switch]$SkipEvents,
    [switch]$SkipKargo,
    [switch]$SkipCertManager
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Installing GitOps Platform Stack" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Verify cluster access
Write-Host "Verifying Kubernetes cluster access..." -ForegroundColor Green
kubectl cluster-info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Cannot access Kubernetes cluster. Check kubeconfig."
    exit 1
}

$ClusterInfo = kubectl cluster-info
Write-Host $ClusterInfo -ForegroundColor Yellow
Write-Host ""

# Track installation status
$Installed = @()
$Failed = @()

# 1. cert-manager (required by Kargo and for TLS)
if (-not $SkipCertManager) {
    Write-Host "Step 1: Installing cert-manager..." -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    try {
        if ($Email) {
            & "$ScriptDir\install-cert-manager.ps1" -Email $Email
        } else {
            & "$ScriptDir\install-cert-manager.ps1" -ConfigureLetsEncrypt $false
        }
        if ($LASTEXITCODE -eq 0) {
            $Installed += "cert-manager"
        } else {
            $Failed += "cert-manager"
        }
    } catch {
        Write-Error "cert-manager installation failed: $_"
        $Failed += "cert-manager"
    }
    Write-Host ""
}

# 2. Istio (service mesh)
if (-not $SkipIstio) {
    Write-Host "Step 2: Installing Istio..." -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    try {
        & "$ScriptDir\install-istio.ps1"
        if ($LASTEXITCODE -eq 0) {
            $Installed += "Istio"
        } else {
            $Failed += "Istio"
        }
    } catch {
        Write-Error "Istio installation failed: $_"
        $Failed += "Istio"
    }
    Write-Host ""
}

# 3. ArgoCD (GitOps continuous delivery)
if (-not $SkipArgoCD) {
    Write-Host "Step 3: Installing ArgoCD..." -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    try {
        & "$ScriptDir\install-argocd.ps1"
        if ($LASTEXITCODE -eq 0) {
            $Installed += "ArgoCD"
        } else {
            $Failed += "ArgoCD"
        }
    } catch {
        Write-Error "ArgoCD installation failed: $_"
        $Failed += "ArgoCD"
    }
    Write-Host ""
}

# 4. Argo Rollouts (progressive delivery)
if (-not $SkipRollouts) {
    Write-Host "Step 4: Installing Argo Rollouts..." -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    try {
        & "$ScriptDir\install-argo-rollouts.ps1"
        if ($LASTEXITCODE -eq 0) {
            $Installed += "Argo Rollouts"
        } else {
            $Failed += "Argo Rollouts"
        }
    } catch {
        Write-Error "Argo Rollouts installation failed: $_"
        $Failed += "Argo Rollouts"
    }
    Write-Host ""
}

# 5. Argo Events (event-driven automation)
if (-not $SkipEvents) {
    Write-Host "Step 5: Installing Argo Events..." -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    try {
        & "$ScriptDir\install-argo-events.ps1"
        if ($LASTEXITCODE -eq 0) {
            $Installed += "Argo Events"
        } else {
            $Failed += "Argo Events"
        }
    } catch {
        Write-Error "Argo Events installation failed: $_"
        $Failed += "Argo Events"
    }
    Write-Host ""
}

# 6. Kargo (promotion workflows)
if (-not $SkipKargo) {
    Write-Host "Step 6: Installing Kargo..." -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    try {
        & "$ScriptDir\install-kargo.ps1"
        if ($LASTEXITCODE -eq 0) {
            $Installed += "Kargo"
        } else {
            $Failed += "Kargo"
        }
    } catch {
        Write-Error "Kargo installation failed: $_"
        $Failed += "Kargo"
    }
    Write-Host ""
}
# 7. Kubernetes Dashboard (Kubernetes UI)
if (-not $SkipDashboard) {
    Write-Host "Step 7: Installing Kubernetes Dashboard..." -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    try {
        & "$ScriptDir\install-kubernetes-dashboard.ps1"
        if ($LASTEXITCODE -eq 0) {
            $Installed += "Kubernetes Dashboard"
        } else {
            $Failed += "Kubernetes Dashboard"
        }
    } catch {
        Write-Error "Kubernetes Dashboard installation failed: $_"
        $Failed += "Kubernetes Dashboard"
    }
    Write-Host ""
}

# 
# Installation summary
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Installation Summary" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""|headlamp"

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Access ArgoCD UI and change default password" -ForegroundColor White
Write-Host "  2. Access Kubernetes Dashboard for cluster management" -ForegroundColor White
Write-Host "  3. Configure Istio ingress gateway" -ForegroundColor White
Write-Host "  4. Create ArgoCD applications for your services" -ForegroundColor White
Write-Host "  5. Set up Kargo projects and promotion workflows" -ForegroundColor White
Write-Host "  6

if ($Failed.Count -gt 0) {
    Write-Host "Failed to install:" -ForegroundColor Red
    foreach ($tool in $Failed) {
        Write-Host "  ✗ $tool" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "Platform components:" -ForegroundColor Cyan
kubectl get pods --all-namespaces | Select-String "istio|argocd|argo-|kargo|cert-manager"

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Access ArgoCD UI and change default password" -ForegroundColor White
Write-Host "  2. Configure Istio ingress gateway" -ForegroundColor White
Write-Host "  3. Create ArgoCD applications for your services" -ForegroundColor White
Write-Host "  4. Set up Kargo projects and promotion workflows" -ForegroundColor White
Write-Host "  5. Deploy your first application using cw-service chart" -ForegroundColor White
