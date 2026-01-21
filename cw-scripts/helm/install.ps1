#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install cw-service chart with specified values file

.DESCRIPTION
    Installs the cw-service Helm chart into Kubernetes cluster with environment-specific configuration.
    Automatically creates namespace if it doesn't exist.

.PARAMETER ReleaseName
    Name of the Helm release (default: nginx)

.PARAMETER ValuesFile
    Path to values file (default: nginx-dev-values.yaml)

.PARAMETER Namespace
    Kubernetes namespace (default: default)

.PARAMETER DryRun
    Perform a dry-run to validate without installing

.EXAMPLE
    .\install.ps1
    # Installs nginx with dev values to default namespace

.EXAMPLE
    .\install.ps1 -ReleaseName nginx-prod -ValuesFile nginx-prod-values.yaml -Namespace production

.EXAMPLE
    .\install.ps1 -DryRun
    # Validate configuration without installing
#>

param(
    [string]$ReleaseName = "nginx",
    [string]$ValuesFile = "nginx-dev-values.yaml",
    [string]$Namespace = "default",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ChartPath = Join-Path $ScriptDir "..\..\cw-service"
$ValuesPath = Join-Path $ScriptDir $ValuesFile

# Validate chart exists
if (-not (Test-Path $ChartPath)) {
    Write-Error "Chart not found at: $ChartPath"
    exit 1
}

# Validate values file exists
if (-not (Test-Path $ValuesPath)) {
    Write-Error "Values file not found at: $ValuesPath"
    exit 1
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Installing cw-service Chart" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Release Name: $ReleaseName" -ForegroundColor Yellow
Write-Host "Namespace:    $Namespace" -ForegroundColor Yellow
Write-Host "Values File:  $ValuesFile" -ForegroundColor Yellow
Write-Host "Chart Path:   $ChartPath" -ForegroundColor Yellow
Write-Host ""

# Create namespace if it doesn't exist
Write-Host "Checking namespace..." -ForegroundColor Green
kubectl get namespace $Namespace 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating namespace: $Namespace" -ForegroundColor Yellow
    kubectl create namespace $Namespace
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create namespace"
        exit 1
    }
}

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

# Build helm install command
$HelmArgs = @(
    "install", $ReleaseName, $ChartPath,
    "--namespace", $Namespace,
    "--values", $ValuesPath,
    "--create-namespace"
)

if ($DryRun) {
    $HelmArgs += @("--dry-run", "--debug")
    Write-Host "Running dry-run validation..." -ForegroundColor Green
} else {
    Write-Host "Installing release..." -ForegroundColor Green
}

# Execute helm install
& helm $HelmArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "Installation completed successfully!" -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Get release status:" -ForegroundColor Cyan
    Write-Host "  helm status $ReleaseName -n $Namespace" -ForegroundColor White
    Write-Host ""
    Write-Host "Get pods:" -ForegroundColor Cyan
    Write-Host "  kubectl get pods -n $Namespace -l app.kubernetes.io/instance=$ReleaseName" -ForegroundColor White
    Write-Host ""
    Write-Host "Get service:" -ForegroundColor Cyan
    Write-Host "  kubectl get svc -n $Namespace -l app.kubernetes.io/instance=$ReleaseName" -ForegroundColor White
} else {
    Write-Error "Installation failed!"
    exit 1
}
