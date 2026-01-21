#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install ArgoCD - Declarative GitOps CD for Kubernetes

.DESCRIPTION
    Installs ArgoCD using official manifests with optional ingress and SSO configuration.

.PARAMETER Version
    ArgoCD version to install (default: latest stable)

.PARAMETER Namespace
    Namespace for ArgoCD (default: argocd)

.PARAMETER ExposeUI
    Expose ArgoCD UI via LoadBalancer or NodePort (default: true)

.PARAMETER ServiceType
    Service type for UI: LoadBalancer, NodePort, ClusterIP (default: LoadBalancer)

.EXAMPLE
    .\install-argocd.ps1
    # Install latest ArgoCD

.EXAMPLE
    .\install-argocd.ps1 -Version v2.9.3 -ServiceType NodePort

.EXAMPLE
    .\install-argocd.ps1 -ExposeUI $false
    # Install without exposing UI (use port-forward)
#>

param(
    [string]$Version = "",
    [string]$Namespace = "argocd",
    [bool]$ExposeUI = $true,
    [ValidateSet("LoadBalancer", "NodePort", "ClusterIP")]
    [string]$ServiceType = "LoadBalancer"
)

$ErrorActionPreference = "Stop"

# Load versions from central configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VersionsFile = Join-Path $ScriptDir "versions.psd1"
if (Test-Path $VersionsFile) {
    $Versions = Import-PowerShellDataFile -Path $VersionsFile
    if (-not $Version) {
        $Version = $Versions.ArgoCD
    }
} elseif (-not $Version) {
    $Version = "stable"  # Fallback default
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Installing ArgoCD" -ForegroundColor Cyan
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

# Add ArgoCD Helm repository
Write-Host "Adding ArgoCD Helm repository..." -ForegroundColor Green
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Prepare Helm values
$HelmValues = @()
if ($ExposeUI) {
    $HelmValues += "--set", "server.service.type=$ServiceType"
}

# Install ArgoCD using Helm
Write-Host "Installing ArgoCD via Helm..." -ForegroundColor Green
$InstallCmd = @(
    "install", "argocd", "argo/argo-cd",
    "--namespace", $Namespace,
    "--create-namespace",
    "--wait"
)
if ($Version -ne "stable") {
    $InstallCmd += "--version", $Version
}
$InstallCmd += $HelmValues

& helm $InstallCmd

if ($LASTEXITCODE -ne 0) {
    Write-Error "ArgoCD installation failed"
    exit 1
}

# Get initial admin password
Write-Host ""
Write-Host "Retrieving initial admin password..." -ForegroundColor Green
$AdminPassword = kubectl get secret argocd-initial-admin-secret -n $Namespace -o jsonpath="{.data.password}" 2>$null
if ($AdminPassword) {
    $DecodedPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($AdminPassword))
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "ArgoCD installed successfully!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "ArgoCD components:" -ForegroundColor Cyan
kubectl get pods -n $Namespace
Write-Host ""

if ($ExposeUI) {
    Write-Host "ArgoCD UI Service:" -ForegroundColor Cyan
    kubectl get svc argocd-server -n $Namespace
    Write-Host ""
}

Write-Host "Login credentials:" -ForegroundColor Cyan
Write-Host "  Username: admin" -ForegroundColor White
if ($DecodedPassword) {
    Write-Host "  Password: $DecodedPassword" -ForegroundColor White
} else {
    Write-Host "  Password: Run this command:" -ForegroundColor Yellow
    Write-Host "    kubectl get secret argocd-initial-admin-secret -n $Namespace -o jsonpath=`"{.data.password}`" | base64 -d" -ForegroundColor White
}
Write-Host ""
Write-Host "Access ArgoCD UI:" -ForegroundColor Cyan
if ($ServiceType -eq "LoadBalancer") {
    Write-Host "  Wait for external IP, then browse to http://<EXTERNAL-IP>" -ForegroundColor White
    Write-Host "  kubectl get svc argocd-server -n $Namespace" -ForegroundColor White
} elseif ($ServiceType -eq "NodePort") {
    Write-Host "  kubectl get svc argocd-server -n $Namespace" -ForegroundColor White
    Write-Host "  Browse to http://<NODE-IP>:<NODE-PORT>" -ForegroundColor White
} else {
    Write-Host "  Port forward: kubectl port-forward svc/argocd-server -n $Namespace 8080:443" -ForegroundColor White
    Write-Host "  Browse to: https://localhost:8080" -ForegroundColor White
}
Write-Host ""
Write-Host "Install ArgoCD CLI:" -ForegroundColor Cyan
Write-Host "  https://argo-cd.readthedocs.io/en/stable/cli_installation/" -ForegroundColor White
