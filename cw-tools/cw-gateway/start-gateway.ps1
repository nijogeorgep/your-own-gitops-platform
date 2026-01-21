#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Start platform gateway port-forward as a background job

.DESCRIPTION
    Starts the Istio ingress gateway port-forward as a PowerShell background job
    so it keeps running even after closing the terminal.

.PARAMETER Port
    Local port to forward to (default: 8080)

.EXAMPLE
    .\start-gateway.ps1
    # Start gateway port-forward in background

.EXAMPLE
    .\start-gateway.ps1 -Port 9090
    # Start on custom port
#>

param(
    [int]$Port = 8080
)

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Starting Platform Gateway (Background)" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Check if gateway service exists
kubectl get svc istio-ingress -n istio-ingress 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Istio ingress service not found. Run .\apply.ps1 first."
    exit 1
}

# Check if port is already in use
$ExistingJob = Get-Job -Name "GatewayPortForward" -ErrorAction SilentlyContinue
if ($ExistingJob) {
    Write-Host "Existing port-forward found. Stopping it..." -ForegroundColor Yellow
    Stop-Job -Name "GatewayPortForward"
    Remove-Job -Name "GatewayPortForward"
}

# Start port-forward as background job
$Job = Start-Job -Name "GatewayPortForward" -ScriptBlock {
    param($Port)
    kubectl port-forward -n istio-ingress svc/istio-ingress ${Port}:80
} -ArgumentList $Port

Start-Sleep -Seconds 2

if ($Job.State -eq "Running") {
    Write-Host "✓ Gateway port-forward started successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Access your UIs at:" -ForegroundColor Cyan
    Write-Host "  • ArgoCD:   http://localhost:$Port/argocd" -ForegroundColor White
    Write-Host "  • Headlamp: http://localhost:$Port/headlamp" -ForegroundColor White
    Write-Host "  • Rollouts: http://localhost:$Port/rollouts" -ForegroundColor White
    Write-Host ""
    Write-Host "Management commands:" -ForegroundColor Cyan
    Write-Host "  Check status:  Get-Job -Name GatewayPortForward" -ForegroundColor Gray
    Write-Host "  View output:   Receive-Job -Name GatewayPortForward -Keep" -ForegroundColor Gray
    Write-Host "  Stop gateway:  Stop-Job -Name GatewayPortForward; Remove-Job -Name GatewayPortForward" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Error "Failed to start port-forward. Check job output:"
    Receive-Job -Job $Job
    Remove-Job -Job $Job
    exit 1
}
