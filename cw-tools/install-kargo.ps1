#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install Kargo - Advanced promotion workflows for GitOps

.DESCRIPTION
    Installs Kargo for multi-stage environment promotions with ArgoCD integration.

.PARAMETER Version
    Kargo version (default: v0.6.0)

.PARAMETER Namespace
    Namespace for Kargo (default: kargo)

.EXAMPLE
    .\install-kargo.ps1
    # Install with defaults

.EXAMPLE
    .\install-kargo.ps1 -Version v0.5.0
#>

param(
    [string]$Version = "",
    [string]$Namespace = "kargo"
)

$ErrorActionPreference = "Stop"

# Load versions from central configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VersionsFile = Join-Path $ScriptDir "versions.psd1"
if (Test-Path $VersionsFile) {
    $Versions = Import-PowerShellDataFile -Path $VersionsFile
    if (-not $Version) {
        $Version = $Versions.Kargo
    }
} elseif (-not $Version) {
    $Version = "0.6.0"  # Fallback default
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Installing Kargo" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Version:   $Version" -ForegroundColor Yellow
Write-Host "Namespace: $Namespace" -ForegroundColor Yellow
Write-Host ""

# Check if cert-manager is installed (required for Kargo)
Write-Host "Checking for cert-manager..." -ForegroundColor Green
kubectl get namespace cert-manager 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "cert-manager not found. Kargo requires cert-manager."
    Write-Host "Install cert-manager first: .\install-cert-manager.ps1" -ForegroundColor Yellow
    Write-Host "Continuing anyway..." -ForegroundColor Yellow
}

# Create namespace
Write-Host "Creating namespace: $Namespace" -ForegroundColor Green
kubectl create namespace $Namespace 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Namespace already exists" -ForegroundColor Yellow
}

# Install Kargo using OCI Helm chart
Write-Host "Installing Kargo via Helm (OCI registry)..." -ForegroundColor Green
helm install kargo `
    oci://ghcr.io/akuity/kargo-charts/kargo `
    --namespace $Namespace `
    --create-namespace `
    --version $Version `
    --wait

if ($LASTEXITCODE -ne 0) {
    Write-Error "Kargo installation failed"
    exit 1
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Kargo installed successfully!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Kargo components:" -ForegroundColor Cyan
kubectl get pods -n $Namespace
Write-Host ""
Write-Host "Kargo CRDs:" -ForegroundColor Cyan
kubectl get crds | Select-String "kargo"
Write-Host ""
Write-Host "Extract default values (optional):" -ForegroundColor Cyan
Write-Host "  helm inspect values oci://ghcr.io/akuity/kargo-charts/kargo > kargo-values.yaml" -ForegroundColor White
Write-Host ""
Write-Host "Upgrade with custom values:" -ForegroundColor Cyan
Write-Host "  helm upgrade kargo oci://ghcr.io/akuity/kargo-charts/kargo -n $Namespace --values kargo-values.yaml" -ForegroundColor White
Write-Host ""
Write-Host "Install Kargo CLI:" -ForegroundColor Cyan
Write-Host "  https://github.com/akuity/kargo/releases" -ForegroundColor White
Write-Host ""
Write-Host "Access Kargo UI:" -ForegroundColor Cyan
Write-Host "  kubectl port-forward svc/kargo-api -n $Namespace 8080:80" -ForegroundColor White
Write-Host "  Browse to: http://localhost:8080" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Create Project: kubectl apply -f project.yaml" -ForegroundColor White
Write-Host "  2. Create Warehouse: kubectl apply -f warehouse.yaml" -ForegroundColor White
Write-Host "  3. Create Stages: kubectl apply -f stages.yaml" -ForegroundColor White
Write-Host "  4. Create Promotion: kubectl apply -f promotion.yaml" -ForegroundColor White
