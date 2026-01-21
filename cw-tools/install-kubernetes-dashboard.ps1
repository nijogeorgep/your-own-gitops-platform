#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install Kubernetes Dashboard

.DESCRIPTION
    Installs Kubernetes Dashboard web UI for cluster management using Helm.
    Kubernetes Dashboard is the official web-based UI for Kubernetes clusters.
    See: https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/

.PARAMETER Version
    Kubernetes Dashboard Helm chart version to install (default: from versions.psd1)

.PARAMETER Namespace
    Kubernetes namespace for Dashboard (default: kubernetes-dashboard)

.PARAMETER ServiceType
    Kubernetes service type: ClusterIP, LoadBalancer, NodePort (default: ClusterIP)

.PARAMETER SkipVerify
    Skip cluster verification before installation

.EXAMPLE
    .\install-kubernetes-dashboard.ps1
    # Install Kubernetes Dashboard with default configuration

.EXAMPLE
    .\install-kubernetes-dashboard.ps1 -ServiceType LoadBalancer
    # Install with LoadBalancer service for external access

.EXAMPLE
    .\install-kubernetes-dashboard.ps1 -Namespace kube-system
    # Install in kube-system namespace
#>

param(
    [string]$Version = "",
    [string]$Namespace = "kubernetes-dashboard",
    [ValidateSet("ClusterIP", "LoadBalancer", "NodePort")]
    [string]$ServiceType = "ClusterIP",
    [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"

# Load versions from central configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VersionsFile = Join-Path $ScriptDir "versions.psd1"
if (Test-Path $VersionsFile) {
    $Versions = Import-PowerShellDataFile -Path $VersionsFile
    if (-not $Version) {
        $Version = $Versions.KubernetesDashboard
    }
} elseif (-not $Version) {
    $Version = "7.11.0"  # Fallback default
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Installing Kubernetes Dashboard" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Version:      $Version" -ForegroundColor Yellow
Write-Host "Namespace:    $Namespace" -ForegroundColor Yellow
Write-Host "Service Type: $ServiceType" -ForegroundColor Yellow
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

# Create namespace
Write-Host "Creating namespace: $Namespace" -ForegroundColor Green
kubectl create namespace $Namespace 2>&1 | Out-Null

# Add Kubernetes Dashboard Helm repository
Write-Host "Adding Kubernetes Dashboard Helm repository..." -ForegroundColor Green
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/ 2>&1 | Out-Null
helm repo update

Write-Host ""
Write-Host "Installing Kubernetes Dashboard via Helm..." -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard `
    --version $Version `
    --namespace $Namespace `
    --set service.type=$ServiceType `
    --set protocolHttp=true `
    --set service.externalPort=80 `
    --set rbac.clusterReadOnlyRole=true `
    --wait

if ($LASTEXITCODE -ne 0) {
    Write-Error "Kubernetes Dashboard installation failed"
    exit 1
}

# Wait for deployment to be ready
Write-Host ""
Write-Host "Waiting for Kubernetes Dashboard to be ready..." -ForegroundColor Green
kubectl wait --for=condition=available --timeout=300s deployment/kubernetes-dashboard-web -n $Namespace 2>&1 | Out-Null
kubectl wait --for=condition=available --timeout=300s deployment/kubernetes-dashboard-api -n $Namespace 2>&1 | Out-Null

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Kubernetes Dashboard installed successfully!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Dashboard components:" -ForegroundColor Cyan
kubectl get pods -n $Namespace

Write-Host ""
Write-Host "Dashboard services:" -ForegroundColor Cyan
kubectl get svc -n $Namespace

Write-Host ""
Write-Host "Access Kubernetes Dashboard:" -ForegroundColor Cyan
if ($ServiceType -eq "LoadBalancer") {
    Write-Host "  Wait for external IP:" -ForegroundColor White
    Write-Host "    kubectl get svc kubernetes-dashboard-kong-proxy -n $Namespace" -ForegroundColor White
    Write-Host "  Then browse to: http://<EXTERNAL-IP>" -ForegroundColor White
} elseif ($ServiceType -eq "NodePort") {
    $NodePort = kubectl get svc kubernetes-dashboard-kong-proxy -n $Namespace -o jsonpath='{.spec.ports[0].nodePort}' 2>$null
    if ($NodePort) {
        Write-Host "  NodePort: $NodePort" -ForegroundColor White
        Write-Host "  Access via: http://<NODE-IP>:$NodePort" -ForegroundColor White
    }
} else {
    Write-Host "  Port-forward to access locally:" -ForegroundColor White
    Write-Host "    kubectl -n $Namespace port-forward svc/kubernetes-dashboard-kong-proxy 8443:443" -ForegroundColor White
    Write-Host "  Then browse to: https://localhost:8443" -ForegroundColor White
}

Write-Host ""
Write-Host "Authentication:" -ForegroundColor Cyan
Write-Host "  Kubernetes Dashboard uses service account tokens for authentication" -ForegroundColor White
Write-Host ""
Write-Host "  Create admin user (for testing only - NOT for production):" -ForegroundColor Yellow
Write-Host "    kubectl create serviceaccount admin-user -n $Namespace" -ForegroundColor White
Write-Host "    kubectl create clusterrolebinding admin-user --clusterrole=cluster-admin --serviceaccount=${Namespace}:admin-user" -ForegroundColor White
Write-Host ""
Write-Host "  Get token:" -ForegroundColor Yellow
Write-Host "    kubectl -n $Namespace create token admin-user" -ForegroundColor White
Write-Host ""
Write-Host "  ⚠️  WARNING: cluster-admin role grants full access. Use RBAC for production!" -ForegroundColor Red
Write-Host ""
Write-Host "  Docs: https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/" -ForegroundColor White

Write-Host ""
Write-Host "Verify installation:" -ForegroundColor Cyan
Write-Host "  kubectl get all -n $Namespace" -ForegroundColor White
Write-Host "  helm ls -n $Namespace" -ForegroundColor White
