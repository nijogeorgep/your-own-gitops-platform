#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install Istio service mesh on Kubernetes cluster using Helm

.DESCRIPTION
    Installs Istio using Helm charts with production-ready configuration.
    Installs base chart (CRDs), istiod (control plane), and optionally ingress gateway.
    See: https://istio.io/latest/docs/setup/install/helm/

.PARAMETER Version
    Istio Helm chart version to install (default: from versions.psd1)

.PARAMETER IngressGateway
    Install ingress gateway (default: true)

.PARAMETER IngressNamespace
    Namespace for ingress gateway (default: istio-ingress)

.PARAMETER SkipVerify
    Skip cluster verification before installation

.EXAMPLE
    .\install-istio.ps1
    # Install Istio with default configuration

.EXAMPLE
    .\install-istio.ps1 -IngressGateway $false
    # Install without ingress gateway

.EXAMPLE
    .\install-istio.ps1 -Version 1.28.0
    # Install specific version
#>

param(
    [string]$Version = "",
    [bool]$IngressGateway = $true,
    [string]$IngressNamespace = "istio-ingress",
    [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"

# Load versions from central configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VersionsFile = Join-Path $ScriptDir "versions.psd1"
if (Test-Path $VersionsFile) {
    $Versions = Import-PowerShellDataFile -Path $VersionsFile
    if (-not $Version) {
        $Version = $Versions.Istio
    }
} elseif (-not $Version) {
    $Version = "1.28.3"  # Fallback default
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Installing Istio Service Mesh (Helm)" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Version: $Version" -ForegroundColor Yellow
Write-Host "Namespace: istio-system" -ForegroundColor Yellow
Write-Host ""

# Verify cluster access
if (-not $SkipVerify) {
    Write-Host "Verifying cluster access..." -ForegroundColor Green
    kubectl cluster-info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Cannot access Kubernetes cluster. Check kubeconfig."
        exit 1
    }
}

# Add Istio Helm repository
Write-Host "Adding Istio Helm repository..." -ForegroundColor Green
helm repo add istio https://istio-release.storage.googleapis.com/charts 2>&1 | Out-Null
helm repo update

Write-Host ""
Write-Host "Step 1/3: Installing Istio base (CRDs)..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
helm install istio-base istio/base `
    --version $Version `
    --namespace istio-system `
    --create-namespace `
    --set defaultRevision=default `
    --wait

if ($LASTEXITCODE -ne 0) {
    Write-Error "Istio base installation failed"
    exit 1
}

# Verify base chart installation
Write-Host ""
Write-Host "Verifying base chart installation..." -ForegroundColor Green
helm ls -n istio-system

Write-Host ""
Write-Host "Step 2/3: Installing Istiod (control plane)..." -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
helm install istiod istio/istiod `
    --version $Version `
    --namespace istio-system `
    --wait

if ($LASTEXITCODE -ne 0) {
    Write-Error "Istiod installation failed"
    exit 1
}

# Verify istiod installation
Write-Host ""
Write-Host "Verifying istiod installation..." -ForegroundColor Green
kubectl get deployments -n istio-system

# Install Istio Ingress Gateway if requested
if ($IngressGateway) {
    Write-Host ""
    Write-Host "Step 3/3: Installing Istio Ingress Gateway..." -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    
    # Create ingress namespace
    kubectl create namespace $IngressNamespace 2>&1 | Out-Null
    
    helm install istio-ingress istio/gateway `
        --version $Version `
        --namespace $IngressNamespace `
        --wait
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Istio ingress gateway installation failed"
        exit 1
    }
    
    Write-Host ""
    Write-Host "Ingress gateway installed in namespace: $IngressNamespace" -ForegroundColor Green
    kubectl get pods -n $IngressNamespace
} else {
    Write-Host ""
    Write-Host "Step 3/3: Skipping ingress gateway installation" -ForegroundColor Yellow
}

# Label default namespace for sidecar injection
Write-Host ""
Write-Host "Configuring default namespace for sidecar injection..." -ForegroundColor Green
kubectl label namespace default istio-injection=enabled --overwrite

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Istio installed successfully!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installed Helm releases:" -ForegroundColor Cyan
helm ls -n istio-system
if ($IngressGateway) {
    helm ls -n $IngressNamespace
}

Write-Host ""
Write-Host "Istio components:" -ForegroundColor Cyan
kubectl get pods -n istio-system

if ($IngressGateway) {
    Write-Host ""
    Write-Host "Ingress gateway:" -ForegroundColor Cyan
    kubectl get pods -n $IngressNamespace
    kubectl get svc -n $IngressNamespace
}

Write-Host ""
Write-Host "Namespaces with sidecar injection enabled:" -ForegroundColor Cyan
kubectl get namespaces -l istio-injection=enabled

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Deploy applications to namespaces with istio-injection label" -ForegroundColor White
Write-Host "  2. Configure Gateway and VirtualService for traffic routing" -ForegroundColor White
Write-Host "  3. Enable mTLS if needed: kubectl apply -f <peer-authentication.yaml>" -ForegroundColor White
Write-Host ""
Write-Host "Enable sidecar injection for other namespaces:" -ForegroundColor Cyan
Write-Host "  kubectl label namespace <namespace> istio-injection=enabled" -ForegroundColor White
Write-Host ""
Write-Host "Verify installation:" -ForegroundColor Cyan
Write-Host "  kubectl get all -n istio-system" -ForegroundColor White
Write-Host "  helm ls -n istio-system" -ForegroundColor White
