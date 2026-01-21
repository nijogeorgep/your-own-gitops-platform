#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Enable ArgoCD application sharding for scaling to 1000+ services.

.DESCRIPTION
    Configures ArgoCD to distribute Application management across multiple
    controller replicas. This is essential for managing 500+ services efficiently.

.PARAMETER Replicas
    Number of application controller replicas (default: 3)
    Recommended: 3 for 1000-3000 apps, 5 for 5000+ apps

.PARAMETER ApplyChanges
    Apply changes immediately (requires restart of controllers)

.EXAMPLE
    .\enable-sharding.ps1
    Configure sharding with 3 replicas (dry-run)

.EXAMPLE
    .\enable-sharding.ps1 -ApplyChanges
    Configure and apply sharding

.EXAMPLE
    .\enable-sharding.ps1 -Replicas 5 -ApplyChanges
    Configure sharding with 5 replicas for 5000+ services
#>

param(
    [Parameter()]
    [int]$Replicas = 3,
    
    [Parameter()]
    [switch]$ApplyChanges
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "ArgoCD Application Sharding Configuration" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if ArgoCD is installed
try {
    kubectl get namespace argocd | Out-Null
    Write-Host "✓ ArgoCD namespace found" -ForegroundColor Green
} catch {
    Write-Error "ArgoCD namespace not found. Install ArgoCD first."
    exit 1
}

# Check current configuration
Write-Host "`nCurrent Configuration:" -ForegroundColor Yellow
$currentReplicas = kubectl get deployment argocd-application-controller -n argocd -o jsonpath='{.spec.replicas}' 2>$null
if ($currentReplicas) {
    Write-Host "  Application Controller Replicas: $currentReplicas"
} else {
    Write-Host "  Application Controller Replicas: Not found" -ForegroundColor Red
}

$shardingEnabled = kubectl get configmap argocd-cmd-params-cm -n argocd -o jsonpath='{.data.application\.controller\.sharding\.enabled}' 2>$null
if ($shardingEnabled) {
    Write-Host "  Sharding Enabled: $shardingEnabled"
} else {
    Write-Host "  Sharding Enabled: false (default)"
}

# Sharding configuration
Write-Host "`nNew Configuration:" -ForegroundColor Yellow
Write-Host "  Replicas: $Replicas"
Write-Host "  Sharding: Enabled"
Write-Host "  Algorithm: round-robin"

# Calculate capacity
$appsPerShard = 1000
$totalCapacity = $Replicas * $appsPerShard
Write-Host "`nEstimated Capacity:" -ForegroundColor Cyan
Write-Host "  Apps per shard: ~$appsPerShard"
Write-Host "  Total capacity: ~$totalCapacity applications"
Write-Host "  (3 environments × $([Math]::Floor($totalCapacity/3)) services)"

if (-not $ApplyChanges) {
    Write-Host "`n⚠️  DRY RUN MODE - No changes will be applied" -ForegroundColor Yellow
    Write-Host "Run with -ApplyChanges to apply configuration" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Commands that would be executed:" -ForegroundColor Gray
    Write-Host ""
}

# Configuration commands
$commands = @(
    @{
        Description = "Update ArgoCD ConfigMap with sharding settings"
        Command = "kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{`"data`":{`"application.controller.replicas`":`"$Replicas`",`"application.controller.sharding.enabled`":`"true`",`"application.controller.sharding.algorithm`":`"round-robin`"}}'"
    },
    @{
        Description = "Scale application controller StatefulSet"
        Command = "kubectl scale statefulset argocd-application-controller -n argocd --replicas=$Replicas"
    },
    @{
        Description = "Restart application controller (apply changes)"
        Command = "kubectl rollout restart statefulset argocd-application-controller -n argocd"
    }
)

foreach ($cmd in $commands) {
    Write-Host $cmd.Description -ForegroundColor Cyan
    Write-Host "  $($cmd.Command)" -ForegroundColor Gray
    
    if ($ApplyChanges) {
        try {
            Invoke-Expression $cmd.Command | Out-Null
            Write-Host "  ✓ Success" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ Failed: $_" -ForegroundColor Red
        }
    }
    Write-Host ""
}

if ($ApplyChanges) {
    Write-Host "Waiting for controllers to be ready..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
    Write-Host "`nVerifying deployment..." -ForegroundColor Cyan
    kubectl rollout status statefulset argocd-application-controller -n argocd --timeout=5m
    
    Write-Host "`nSharding Status:" -ForegroundColor Green
    kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-application-controller
    
    Write-Host "`nNext Steps:" -ForegroundColor Yellow
    Write-Host "  1. Monitor controller logs: kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f"
    Write-Host "  2. Check Application distribution: kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name} {.metadata.labels.application-controller-shard}{`"`\n`"}{end}'"
    Write-Host "  3. Monitor resource usage: kubectl top pods -n argocd"
} else {
    Write-Host "`nTo apply these changes, run:" -ForegroundColor Yellow
    Write-Host "  .\enable-sharding.ps1 -ApplyChanges" -ForegroundColor White
}

Write-Host ""
Write-Host "Documentation: https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/#argocd-application-controller" -ForegroundColor Gray
