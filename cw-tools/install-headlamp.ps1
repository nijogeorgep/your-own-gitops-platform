#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install Headlamp Kubernetes UI

.DESCRIPTION
    Installs Headlamp web UI for Kubernetes cluster management using Helm.
    Headlamp provides a user-friendly interface for managing Kubernetes resources.
    See: https://headlamp.dev/docs/latest/installation/in-cluster/

.PARAMETER Version
    Headlamp Helm chart version to install (default: from versions.psd1)

.PARAMETER Namespace
    Kubernetes namespace for Headlamp (default: headlamp)

.PARAMETER ServiceType
    Kubernetes service type: ClusterIP, LoadBalancer, NodePort (default: ClusterIP)

.PARAMETER Replicas
    Number of Headlamp replicas (default: 1)

.PARAMETER SkipVerify
    Skip cluster verification before installation

.EXAMPLE
    .\install-headlamp.ps1
    # Install Headlamp with default configuration

.EXAMPLE
    .\install-headlamp.ps1 -ServiceType LoadBalancer
    # Install with LoadBalancer service for external access

.EXAMPLE
    .\install-headlamp.ps1 -Replicas 2 -Namespace kube-system
    # Install with 2 replicas in kube-system namespace
#>

param(
    [string]$Version = "",
    [string]$Namespace = "headlamp",
    [ValidateSet("ClusterIP", "LoadBalancer", "NodePort")]
    [string]$ServiceType = "ClusterIP",
    [int]$Replicas = 1,
    [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"

# Load versions from central configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VersionsFile = Join-Path $ScriptDir "versions.psd1"
if (Test-Path $VersionsFile) {
    $Versions = Import-PowerShellDataFile -Path $VersionsFile
    if (-not $Version) {
        $Version = $Versions.Headlamp
    }
} elseif (-not $Version) {
    $Version = "0.28.1"  # Fallback default
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Installing Headlamp Kubernetes UI" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Version:      $Version" -ForegroundColor Yellow
Write-Host "Namespace:    $Namespace" -ForegroundColor Yellow
Write-Host "Service Type: $ServiceType" -ForegroundColor Yellow
Write-Host "Replicas:     $Replicas" -ForegroundColor Yellow
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

# Add Headlamp Helm repository
Write-Host "Adding Headlamp Helm repository..." -ForegroundColor Green
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/ 2>&1 | Out-Null
helm repo update

Write-Host ""
Write-Host "Installing Headlamp via Helm..." -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

helm install headlamp headlamp/headlamp `
    --version $Version `
    --namespace $Namespace `
    --set replicaCount=$Replicas `
    --set service.type=$ServiceType `
    --wait

if ($LASTEXITCODE -ne 0) {
    Write-Error "Headlamp installation failed"
    exit 1
}

# Wait for deployment to be ready
Write-Host ""
Write-Host "Waiting for Headlamp to be ready..." -ForegroundColor Green
kubectl wait --for=condition=available --timeout=300s deployment/headlamp -n $Namespace

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Headlamp installed successfully!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Headlamp components:" -ForegroundColor Cyan
kubectl get pods -n $Namespace

Write-Host ""
Write-Host "Headlamp service:" -ForegroundColor Cyan
kubectl get svc -n $Namespace

Write-Host ""
Write-Host "Access Headlamp:" -ForegroundColor Cyan
if ($ServiceType -eq "LoadBalancer") {
    Write-Host "  Wait for external IP:" -ForegroundColor White
    Write-Host "    kubectl get svc headlamp -n $Namespace" -ForegroundColor White
    Write-Host "  Then browse to: http://<EXTERNAL-IP>" -ForegroundColor White
} elseif ($ServiceType -eq "NodePort") {
    $NodePort = kubectl get svc headlamp -n $Namespace -o jsonpath='{.spec.ports[0].nodePort}'
    Write-Host "  NodePort: $NodePort" -ForegroundColor White
    Write-Host "  Access via: http://<NODE-IP>:$NodePort" -ForegroundColor White
} else {
    Write-Host "  Port-forward to access locally:" -ForegroundColor White
    Write-Host "    kubectl port-forward -n $Namespace service/headlamp 8080:80" -ForegroundColor White
    Write-Host "  Then browse to: http://localhost:8080" -ForegroundColor White
}

Write-Host ""
Write-Host "Authentication:" -ForegroundColor Cyan
Write-Host "  Headlamp uses your cluster's service account tokens" -ForegroundColor White
Write-Host "  You may need to create a service account with appropriate permissions" -ForegroundColor White
Write-Host "  Docs: https://headlamp.dev/docs/latest/installation/" -ForegroundColor White

Write-Host ""
Write-Host "Verify installation:" -ForegroundColor Cyan
Write-Host "  kubectl get all -n $Namespace" -ForegroundColor White
Write-Host "  helm ls -n $Namespace" -ForegroundColor White
