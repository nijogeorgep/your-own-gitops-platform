#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install Argo Rollouts - Progressive delivery for Kubernetes

.DESCRIPTION
    Installs Argo Rollouts controller for canary and blue-green deployments.
    Includes kubectl plugin and dashboard.

.PARAMETER Version
    Argo Rollouts version (default: v1.6.4)

.PARAMETER Namespace
    Namespace for Argo Rollouts (default: argo-rollouts)

.PARAMETER InstallDashboard
    Install Argo Rollouts dashboard (default: true)

.EXAMPLE
    .\install-argo-rollouts.ps1
    # Install with defaults

.EXAMPLE
    .\install-argo-rollouts.ps1 -Version v1.6.0 -InstallDashboard $false
#>

param(
    [string]$Version = "",
    [string]$Namespace = "argo-rollouts",
    [bool]$InstallDashboard = $true
)

$ErrorActionPreference = "Stop"

# Load versions from central configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VersionsFile = Join-Path $ScriptDir "versions.psd1"
if (Test-Path $VersionsFile) {
    $Versions = Import-PowerShellDataFile -Path $VersionsFile
    if (-not $Version) {
        $Version = $Versions.ArgoRollouts
    }
} elseif (-not $Version) {
    $Version = "2.35.0"  # Fallback default
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Installing Argo Rollouts" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Version:   $Version" -ForegroundColor Yellow
Write-Host "Namespace: $Namespace" -ForegroundColor Yellow
Write-Host ""

# Create namespace
Write-Host "Creating namespace: $Namespace" -ForegroundColor Green
kubectl create namespace $Namespace 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Namespace already exists" -ForegroundColor Yellow
}

# Add ArgoCD Helm repository (contains Argo Rollouts)
Write-Host "Adding Argo Helm repository..." -ForegroundColor Green
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install Argo Rollouts using Helm
Write-Host "Installing Argo Rollouts via Helm..." -ForegroundColor Green
$HelmArgs = @(
    "install", "argo-rollouts", "argo/argo-rollouts",
    "--namespace", $Namespace,
    "--create-namespace",
    "--version", $Version,
    "--wait"
)

if ($InstallDashboard) {
    $HelmArgs += "--set", "dashboard.enabled=true"
}

& helm $HelmArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Argo Rollouts installation failed"
    exit 1
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Argo Rollouts installed successfully!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Argo Rollouts components:" -ForegroundColor Cyan
kubectl get pods -n $Namespace
Write-Host ""
Write-Host "Install kubectl plugin:" -ForegroundColor Cyan
if ($IsWindows -or $env:OS -match "Windows") {
    Write-Host "  Download from: https://github.com/argoproj/argo-rollouts/releases" -ForegroundColor White
    Write-Host "  Place kubectl-argo-rollouts.exe in PATH" -ForegroundColor White
} else {
    Write-Host "  curl -LO https://github.com/argoproj/argo-rollouts/releases/download/$Version/kubectl-argo-rollouts-linux-amd64" -ForegroundColor White
    Write-Host "  chmod +x kubectl-argo-rollouts-linux-amd64" -ForegroundColor White
    Write-Host "  sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts" -ForegroundColor White
}
Write-Host ""
if ($InstallDashboard) {
    Write-Host "Access dashboard:" -ForegroundColor Cyan
    Write-Host "  kubectl port-forward svc/argo-rollouts-dashboard -n $Namespace 3100:3100" -ForegroundColor White
    Write-Host "  Browse to: http://localhost:3100" -ForegroundColor White
    Write-Host ""
}
Write-Host "Verify installation:" -ForegroundColor Cyan
Write-Host "  kubectl argo rollouts version" -ForegroundColor White
Write-Host ""
Write-Host "Example Rollout:" -ForegroundColor Cyan
Write-Host "  kubectl argo rollouts create rollout <name> --image nginx:latest" -ForegroundColor White
