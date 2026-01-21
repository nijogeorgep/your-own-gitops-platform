#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Port-forward the platform gateway for local access

.DESCRIPTION
    Forwards the Istio ingress gateway to localhost:8080 for accessing all platform UIs.
    For Docker Desktop / Kind clusters where LoadBalancer IPs are not directly accessible.

.PARAMETER Port
    Local port to forward to (default: 8080)

.EXAMPLE
    .\port-forward.ps1
    # Forward gateway to localhost:8080

.EXAMPLE
    .\port-forward.ps1 -Port 9090
    # Forward gateway to localhost:9090
#>

param(
    [int]$Port = 8080
)

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Platform Gateway Port-Forward" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Check if gateway service exists
kubectl get svc istio-ingress -n istio-ingress 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Istio ingress service not found. Run .\apply.ps1 first."
    exit 1
}

Write-Host "Starting port-forward to localhost:$Port..." -ForegroundColor Green
Write-Host ""
Write-Host "Access your UIs at:" -ForegroundColor Cyan
Write-Host "  • ArgoCD:   http://localhost:$Port/argocd" -ForegroundColor White
Write-Host "  • Headlamp: http://localhost:$Port/headlamp" -ForegroundColor White
Write-Host "  • Rollouts: http://localhost:$Port/rollouts" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop port-forwarding" -ForegroundColor Yellow
Write-Host ""

# Run port-forward
kubectl port-forward -n istio-ingress svc/istio-ingress ${Port}:80
