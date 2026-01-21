#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy Kargo resources for all or specific services.

.DESCRIPTION
    Applies generated Kargo Project, Warehouse, and Stage resources to the Kubernetes cluster.
    Creates isolated namespaces for each service (kargo-<service-name>).

.PARAMETER ServiceName
    Deploy resources for a specific service. If not specified, deploys all services.

.PARAMETER SkipNamespace
    Skip namespace creation (useful if namespaces already exist)

.EXAMPLE
    .\deploy.ps1
    Deploy Kargo resources for all services

.EXAMPLE
    .\deploy.ps1 -ServiceName nginx
    Deploy resources only for nginx service

.EXAMPLE
    .\deploy.ps1 -SkipNamespace
    Deploy without creating namespaces
#>

param(
    [Parameter(Position = 0)]
    [string]$ServiceName = "all",
    
    [Parameter()]
    [switch]$SkipNamespace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Paths
$scriptDir = $PSScriptRoot
$projectsDir = Join-Path $scriptDir "projects"

# Check if projects directory exists
if (-not (Test-Path $projectsDir)) {
    Write-Error "Projects directory not found. Run .\generate-kargo-resources.ps1 first."
    exit 1
}

# Check if kubectl is available
try {
    kubectl version --client --output=json | Out-Null
} catch {
    Write-Error "kubectl not found. Please install kubectl and configure cluster access."
    exit 1
}

# Check cluster connectivity
try {
    kubectl cluster-info | Out-Null
    Write-Host "✓ Connected to Kubernetes cluster" -ForegroundColor Green
} catch {
    Write-Error "Cannot connect to Kubernetes cluster. Check your kubectl configuration."
    exit 1
}

# Get list of service projects
if ($ServiceName -eq "all") {
    $serviceProjects = Get-ChildItem -Path $projectsDir -Directory
    Write-Host "Deploying Kargo resources for all services..." -ForegroundColor Cyan
} else {
    $servicePath = Join-Path $projectsDir $ServiceName
    if (-not (Test-Path $servicePath)) {
        Write-Error "Generated resources not found for service: $ServiceName. Run .\generate-kargo-resources.ps1 first."
        exit 1
    }
    $serviceProjects = @(Get-Item $servicePath)
    Write-Host "Deploying Kargo resources for service: $ServiceName" -ForegroundColor Cyan
}

# Deploy resources for each service
$successCount = 0
$failCount = 0

foreach ($project in $serviceProjects) {
    $name = $project.Name
    Write-Host "`nDeploying: $name" -ForegroundColor Yellow
    
    try {
        # Apply namespace first (if not skipped)
        if (-not $SkipNamespace) {
            $namespacePath = Join-Path $project.FullName "namespace.yaml"
            if (Test-Path $namespacePath) {
                kubectl apply -f $namespacePath
                Write-Host "  ✓ Applied namespace" -ForegroundColor Green
            }
        }
        
        # Apply project
        $projectPath = Join-Path $project.FullName "project.yaml"
        if (Test-Path $projectPath) {
            kubectl apply -f $projectPath
            Write-Host "  ✓ Applied project" -ForegroundColor Green
        }
        
        # Apply warehouse
        $warehousePath = Join-Path $project.FullName "warehouse.yaml"
        if (Test-Path $warehousePath) {
            kubectl apply -f $warehousePath
            Write-Host "  ✓ Applied warehouse" -ForegroundColor Green
        }
        
        # Apply stages
        $stagesPath = Join-Path $project.FullName "stages.yaml"
        if (Test-Path $stagesPath) {
            kubectl apply -f $stagesPath
            Write-Host "  ✓ Applied stages" -ForegroundColor Green
        }
        
        $successCount++
    } catch {
        Write-Host "  ✗ Failed to deploy $name : $_" -ForegroundColor Red
        $failCount++
    }
}

# Summary
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "Deployment Summary:" -ForegroundColor Cyan
Write-Host "  ✓ Successfully deployed: $successCount service(s)" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "  ✗ Failed: $failCount service(s)" -ForegroundColor Red
}
Write-Host "="*60 -ForegroundColor Cyan

# Verification commands
Write-Host "`nVerification:" -ForegroundColor Yellow
Write-Host "  kubectl get projects --all-namespaces" -ForegroundColor White
Write-Host "  kubectl get warehouses -n kargo-<service-name>" -ForegroundColor White
Write-Host "  kubectl get stages -n kargo-<service-name>" -ForegroundColor White
Write-Host "`nKargo UI: http://localhost:8080/kargo" -ForegroundColor Cyan
