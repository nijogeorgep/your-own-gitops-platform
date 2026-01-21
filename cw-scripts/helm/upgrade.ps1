#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Upgrade existing cw-service chart release

.DESCRIPTION
    Upgrades an existing Helm release with new values or chart version.
    Use --install flag to install if release doesn't exist.

.PARAMETER ReleaseName
    Name of the Helm release (default: nginx)

.PARAMETER ValuesFile
    Path to values file (default: nginx-dev-values.yaml)

.PARAMETER Namespace
    Kubernetes namespace (default: default)

.PARAMETER Install
    Install if release doesn't exist

.PARAMETER DryRun
    Perform a dry-run to validate without upgrading

.EXAMPLE
    .\upgrade.ps1
    # Upgrades nginx release with dev values

.EXAMPLE
    .\upgrade.ps1 -ReleaseName nginx-prod -ValuesFile nginx-prod-values.yaml -Namespace production -Install

.EXAMPLE
    .\upgrade.ps1 -DryRun
    # Preview changes without applying
#>

param(
    [string]$ReleaseName = "nginx",
    [string]$ValuesFile = "nginx-dev-values.yaml",
    [string]$Namespace = "default",
    [switch]$Install,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ChartPath = Join-Path $ScriptDir "..\..\cw-service"
$ValuesPath = Join-Path $ScriptDir $ValuesFile

# Validate paths
if (-not (Test-Path $ChartPath)) {
    Write-Error "Chart not found at: $ChartPath"
    exit 1
}

if (-not (Test-Path $ValuesPath)) {
    Write-Error "Values file not found at: $ValuesPath"
    exit 1
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Upgrading cw-service Chart" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Release Name: $ReleaseName" -ForegroundColor Yellow
Write-Host "Namespace:    $Namespace" -ForegroundColor Yellow
Write-Host "Values File:  $ValuesFile" -ForegroundColor Yellow
Write-Host ""

# Update helm dependencies
Write-Host "Updating Helm dependencies..." -ForegroundColor Green
Push-Location $ChartPath
helm dependency update
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Error "Failed to update dependencies"
    exit 1
}
Pop-Location

# Build helm upgrade command
$HelmArgs = @(
    "upgrade", $ReleaseName, $ChartPath,
    "--namespace", $Namespace,
    "--values", $ValuesPath
)

if ($Install) {
    $HelmArgs += "--install"
    Write-Host "Mode: Upgrade or Install" -ForegroundColor Yellow
}

if ($DryRun) {
    $HelmArgs += @("--dry-run", "--debug")
    Write-Host "Running dry-run validation..." -ForegroundColor Green
} else {
    Write-Host "Upgrading release..." -ForegroundColor Green
}

# Execute helm upgrade
& helm $HelmArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "Upgrade completed successfully!" -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "View rollout status:" -ForegroundColor Cyan
    Write-Host "  kubectl rollout status deployment -n $Namespace -l app.kubernetes.io/instance=$ReleaseName" -ForegroundColor White
    Write-Host ""
    Write-Host "View release history:" -ForegroundColor Cyan
    Write-Host "  helm history $ReleaseName -n $Namespace" -ForegroundColor White
} else {
    Write-Error "Upgrade failed!"
    exit 1
}
