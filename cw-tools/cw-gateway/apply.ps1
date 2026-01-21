#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Apply platform gateway configuration

.DESCRIPTION
    Applies Istio Gateway and VirtualServices to expose platform UIs.
    Also configures ArgoCD for path-based routing.

.EXAMPLE
    .\apply.ps1
    # Apply all gateway configurations
#>

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Applying Platform Gateway Configuration" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Check if Istio is installed
Write-Host "Checking Istio installation..." -ForegroundColor Green
kubectl get deployment istiod -n istio-system 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Istio is not installed. Run install-istio.ps1 first."
    exit 1
}

# Apply Gateway
Write-Host "Creating Istio Gateway..." -ForegroundColor Green
kubectl apply -f "$ScriptDir\gateway.yaml"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create Gateway"
    exit 1
}

Write-Host ""
Write-Host "Creating VirtualServices..." -ForegroundColor Green

# Apply VirtualServices for installed components
$Components = @(
    @{Name="ArgoCD"; Namespace="argocd"; File="argocd-virtualservice.yaml"},
    @{Name="Headlamp"; Namespace="headlamp"; File="headlamp-virtualservice.yaml"},
    @{Name="Kargo"; Namespace="kargo"; File="kargo-virtualservice.yaml"},
    @{Name="Argo Rollouts"; Namespace="argo-rollouts"; File="rollouts-virtualservice.yaml"}
)

foreach ($component in $Components) {
    kubectl get namespace $component.Namespace 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        kubectl apply -f "$ScriptDir\$($component.File)"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ $($component.Name) VirtualService" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $($component.Name) VirtualService (failed)" -ForegroundColor Red
        }
    } else {
        Write-Host "  ⊘ $($component.Name) (not installed)" -ForegroundColor Yellow
    }
}

# Configure ArgoCD for path-based routing
Write-Host ""
Write-Host "Configuring ArgoCD for path-based routing..." -ForegroundColor Green
kubectl get namespace argocd 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.basehref":"/argocd","server.rootpath":"/argocd"}}' 2>&1 | Out-Null
    kubectl rollout restart deployment argocd-server -n argocd 2>&1 | Out-Null
    Write-Host "  ✓ ArgoCD configured for /argocd path" -ForegroundColor Green
    Write-Host "  ⌛ Waiting for ArgoCD server to restart..." -ForegroundColor Yellow
    kubectl rollout status deployment argocd-server -n argocd --timeout=120s 2>&1 | Out-Null
}

# Get gateway external IP
Write-Host ""
Write-Host "Checking gateway external IP..." -ForegroundColor Green
Start-Sleep -Seconds 3

$externalIP = kubectl get svc istio-ingress -n istio-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
if (-not $externalIP) {
    $externalIP = kubectl get svc istio-ingress -n istio-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Platform Gateway Configured Successfully!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""

if ($externalIP) {
    Write-Host "Gateway External IP: $externalIP" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Access UIs at:" -ForegroundColor Cyan
    
    foreach ($component in $Components) {
        kubectl get namespace $component.Namespace 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $path = $component.File -replace "-virtualservice.yaml",""
            Write-Host "  $($component.Name.PadRight(20)) http://${externalIP}/${path}" -ForegroundColor White
        }
    }
} else {
    Write-Host "LoadBalancer IP: <pending>" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "For local clusters, use port-forwarding:" -ForegroundColor Cyan
    Write-Host "  kubectl port-forward -n istio-ingress svc/istio-ingress 8080:80" -ForegroundColor White
    Write-Host ""
    Write-Host "Then access via:" -ForegroundColor Cyan
    Write-Host "  ArgoCD:   http://localhost:8080/argocd" -ForegroundColor White
    Write-Host "  Headlamp: http://localhost:8080/headlamp" -ForegroundColor White
    Write-Host "  Kargo:    http://localhost:8080/kargo" -ForegroundColor White
    Write-Host "  Rollouts: http://localhost:8080/rollouts" -ForegroundColor White
}

Write-Host ""
Write-Host "Verify configuration:" -ForegroundColor Cyan
Write-Host "  kubectl get gateway -n istio-system" -ForegroundColor White
Write-Host "  kubectl get virtualservices -A" -ForegroundColor White
Write-Host "  kubectl get svc istio-ingress -n istio-ingress -w" -ForegroundColor White
