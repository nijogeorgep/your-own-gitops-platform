#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Uninstall cw-service chart release

.DESCRIPTION
    Removes a Helm release and all its associated Kubernetes resources.

.PARAMETER ReleaseName
    Name of the Helm release to uninstall (default: nginx)

.PARAMETER Namespace
    Kubernetes namespace (default: default)

.PARAMETER KeepHistory
    Keep release history for rollback

.EXAMPLE
    .\uninstall.ps1
    # Uninstall nginx release from default namespace

.EXAMPLE
    .\uninstall.ps1 -ReleaseName nginx-prod -Namespace production

.EXAMPLE
    .\uninstall.ps1 -KeepHistory
    # Uninstall but keep history for potential rollback
#>

param(
    [string]$ReleaseName = "nginx",
    [string]$Namespace = "default",
    [switch]$KeepHistory
)

$ErrorActionPreference = "Stop"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Uninstalling cw-service Chart Release" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Release Name: $ReleaseName" -ForegroundColor Yellow
Write-Host "Namespace:    $Namespace" -ForegroundColor Yellow
Write-Host ""

# Check if release exists
Write-Host "Checking if release exists..." -ForegroundColor Green
helm status $ReleaseName -n $Namespace 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Release '$ReleaseName' not found in namespace '$Namespace'"
    exit 0
}

# Show resources that will be deleted
Write-Host "Resources to be deleted:" -ForegroundColor Yellow
kubectl get all -n $Namespace -l app.kubernetes.io/instance=$ReleaseName

Write-Host ""
Write-Host "Are you sure you want to uninstall '$ReleaseName'? (y/N): " -NoNewline -ForegroundColor Red
$Confirmation = Read-Host

if ($Confirmation -ne 'y' -and $Confirmation -ne 'Y') {
    Write-Host "Uninstall cancelled." -ForegroundColor Yellow
    exit 0
}

# Build helm uninstall command
$HelmArgs = @("uninstall", $ReleaseName, "--namespace", $Namespace)

if ($KeepHistory) {
    $HelmArgs += "--keep-history"
    Write-Host "Uninstalling (keeping history)..." -ForegroundColor Green
} else {
    Write-Host "Uninstalling..." -ForegroundColor Green
}

# Execute helm uninstall
& helm $HelmArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "Uninstall completed successfully!" -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
    
    if ($KeepHistory) {
        Write-Host ""
        Write-Host "View release history:" -ForegroundColor Cyan
        Write-Host "  helm history $ReleaseName -n $Namespace" -ForegroundColor White
        Write-Host ""
        Write-Host "Rollback if needed:" -ForegroundColor Cyan
        Write-Host "  helm rollback $ReleaseName <revision> -n $Namespace" -ForegroundColor White
    }
} else {
    Write-Error "Uninstall failed!"
    exit 1
}
