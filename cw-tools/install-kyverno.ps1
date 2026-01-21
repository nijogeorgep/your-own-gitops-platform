#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install Kyverno policy engine for Kubernetes admission control.

.DESCRIPTION
    Installs Kyverno using Helm with high availability configuration.
    Kyverno provides policy-as-code for Kubernetes with validation,
    mutation, and generation capabilities.

.PARAMETER Version
    Kyverno version to install (default: uses version from versions.psd1)

.PARAMETER DryRun
    Preview installation without applying changes

.EXAMPLE
    .\install-kyverno.ps1
    Install Kyverno with default settings

.EXAMPLE
    .\install-kyverno.ps1 -Version "3.1.4"
    Install specific version of Kyverno

.EXAMPLE
    .\install-kyverno.ps1 -DryRun
    Preview installation
#>

param(
    [Parameter()]
    [string]$Version,
    
    [Parameter()]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load versions from central config
$scriptDir = $PSScriptRoot
$versionsFile = Join-Path $scriptDir "versions.psd1"

if (Test-Path $versionsFile) {
    $versions = Import-PowerShellDataFile -Path $versionsFile
    if (-not $Version) {
        $Version = $versions.Kyverno
    }
}

if (-not $Version) {
    $Version = "3.1.4"  # Fallback version
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Installing Kyverno v$Version" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Add Helm repository
Write-Host "Adding Kyverno Helm repository..." -ForegroundColor Yellow
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

# Prepare Helm arguments
$helmArgs = @(
    "upgrade", "kyverno", "kyverno/kyverno",
    "--install",
    "--namespace", "kyverno",
    "--create-namespace",
    "--version", $Version,
    
    # High Availability configuration
    "--set", "admissionController.replicas=3",
    "--set", "backgroundController.replicas=2",
    "--set", "cleanupController.replicas=2",
    "--set", "reportsController.replicas=2",
    
    # Resource requests/limits
    "--set", "admissionController.resources.requests.cpu=100m",
    "--set", "admissionController.resources.requests.memory=128Mi",
    "--set", "admissionController.resources.limits.cpu=1000m",
    "--set", "admissionController.resources.limits.memory=512Mi",
    
    # Enable metrics for Prometheus
    "--set", "admissionController.serviceMonitor.enabled=false",  # Enable if Prometheus installed
    
    # Policy reports
    "--set", "backgroundController.enabled=true",
    "--set", "cleanupController.enabled=true",
    "--set", "reportsController.enabled=true",
    
    # Webhook configuration
    "--set", "admissionController.rbac.create=true",
    
    # Feature flags
    "--set", "features.policyExceptions.enabled=true",
    "--set", "features.generateValidatingAdmissionPolicy.enabled=false",
    
    # Wait for deployment
    "--wait",
    "--timeout", "5m"
)

if ($DryRun) {
    $helmArgs += "--dry-run"
    Write-Host "DRY RUN MODE - No changes will be applied`n" -ForegroundColor Magenta
}

# Install Kyverno
Write-Host "Installing Kyverno..." -ForegroundColor Yellow
try {
    helm @helmArgs
    
    if (-not $DryRun) {
        Write-Host "`n✓ Kyverno installed successfully!" -ForegroundColor Green
        
        # Wait for pods to be ready
        Write-Host "`nWaiting for Kyverno pods to be ready..." -ForegroundColor Yellow
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kyverno -n kyverno --timeout=300s
        
        # Display status
        Write-Host "`nKyverno Status:" -ForegroundColor Cyan
        kubectl get pods -n kyverno
        
        Write-Host "`nNext steps:" -ForegroundColor Yellow
        Write-Host "  1. Deploy policies: cd ..\cw-policies && .\deploy.ps1" -ForegroundColor White
        Write-Host "  2. View policy reports: kubectl get policyreport -A" -ForegroundColor White
        Write-Host "  3. Monitor violations: kubectl get clusterpolicy" -ForegroundColor White
        Write-Host "  4. Kyverno UI (optional): kubectl port-forward -n kyverno svc/kyverno-ui 8080:80" -ForegroundColor White
    }
} catch {
    Write-Host "`n✗ Installation failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================`n" -ForegroundColor Cyan
