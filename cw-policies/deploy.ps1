#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy Kyverno policies to Kubernetes cluster

.DESCRIPTION
    Deploys all or specific categories of Kyverno policies.
    Supports dry-run mode for validation before applying.
    Enforces proper lifecycle: Audit mode first, then Enforce after testing.

.PARAMETER Category
    Policy category to deploy (cluster-policies, mutations, exemptions, all)
    Default: all

.PARAMETER Mode
    Deployment mode: Audit or Enforce
    Default: Audit (safe for initial deployment)

.PARAMETER DryRun
    Validate policies without applying to cluster

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\deploy.ps1
    Deploy all policies in Audit mode (safe, recommended first step)

.EXAMPLE
    .\deploy.ps1 -Category cluster-policies -Mode Enforce
    Deploy cluster policies in Enforce mode (blocks violations)

.EXAMPLE
    .\deploy.ps1 -DryRun
    Validate all policies without applying
#>

param(
    [ValidateSet('all', 'cluster-policies', 'mutations', 'exemptions')]
    [string]$Category = 'all',
    
    [ValidateSet('Audit', 'Enforce')]
    [string]$Mode = 'Audit',
    
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$baseDir = $PSScriptRoot

# Policy directories
$policyDirs = @{
    'cluster-policies' = Join-Path $baseDir 'kyverno\cluster-policies'
    'mutations'        = Join-Path $baseDir 'kyverno\mutations'
    'exemptions'       = Join-Path $baseDir 'kyverno\exemptions'
}

function Write-ColorOutput {
    param([string]$Message, [string]$Color = 'White')
    Write-Host $Message -ForegroundColor $Color
}

function Set-PolicyMode {
    param([string]$FilePath, [string]$Mode)
    
    $content = Get-Content -Path $FilePath -Raw
    $content = $content -replace 'validationFailureAction:\s*(Audit|Enforce)', "validationFailureAction: $Mode"
    Set-Content -Path $FilePath -Value $content -NoNewline
}

function Deploy-Policies {
    param([string]$Directory, [string]$CategoryName)
    
    if (-not (Test-Path $Directory)) {
        Write-ColorOutput "Directory not found: $Directory" 'Yellow'
        return
    }
    
    $policyFiles = Get-ChildItem -Path $Directory -Filter '*.yaml' -File
    
    if ($policyFiles.Count -eq 0) {
        Write-ColorOutput "No policies found in $CategoryName" 'Yellow'
        return
    }
    
    Write-ColorOutput "`n=== Deploying $CategoryName ($($policyFiles.Count) policies) ===" 'Cyan'
    
    foreach ($file in $policyFiles) {
        Write-ColorOutput "  Processing: $($file.Name)" 'Gray'
        
        # Set validation mode for non-exemption policies
        if ($CategoryName -ne 'exemptions') {
            $tempFile = New-TemporaryFile
            Copy-Item -Path $file.FullName -Destination $tempFile.FullName -Force
            Set-PolicyMode -FilePath $tempFile.FullName -Mode $Mode
            $fileToApply = $tempFile.FullName
        } else {
            $fileToApply = $file.FullName
        }
        
        try {
            if ($DryRun) {
                kubectl apply -f $fileToApply --dry-run=client
                Write-ColorOutput "    ✓ Validated" 'Green'
            } else {
                kubectl apply -f $fileToApply
                Write-ColorOutput "    ✓ Deployed" 'Green'
            }
        } catch {
            Write-ColorOutput "    ✗ Failed: $_" 'Red'
        } finally {
            if ($tempFile -and (Test-Path $tempFile.FullName)) {
                Remove-Item $tempFile.FullName -Force
            }
        }
    }
}

# Main execution
Write-ColorOutput @"

╔═══════════════════════════════════════════════════════════╗
║          Kyverno Policy Deployment Script                ║
╚═══════════════════════════════════════════════════════════╝

"@ 'Cyan'

# Verify Kyverno is installed
Write-ColorOutput "Checking Kyverno installation..." 'Gray'
try {
    $kyvernoStatus = kubectl get deployment -n kyverno kyverno-admission-controller -o jsonpath='{.status.availableReplicas}' 2>$null
    if ([int]$kyvernoStatus -lt 1) {
        throw "Kyverno not available"
    }
    Write-ColorOutput "✓ Kyverno is running" 'Green'
} catch {
    Write-ColorOutput "✗ Kyverno is not installed or not ready" 'Red'
    Write-ColorOutput "Run: cd ..\cw-tools; .\install-kyverno.ps1" 'Yellow'
    exit 1
}

# Display deployment plan
Write-ColorOutput "`nDeployment Plan:" 'Cyan'
Write-ColorOutput "  Category: $Category" 'White'
Write-ColorOutput "  Mode: $Mode" 'White'
Write-ColorOutput "  Dry-run: $DryRun" 'White'

if ($Mode -eq 'Enforce' -and -not $Force) {
    Write-ColorOutput "`n⚠️  WARNING: Enforce mode will BLOCK non-compliant resources!" 'Yellow'
    Write-ColorOutput "   Recommended: Test in Audit mode first, monitor PolicyReports" 'Yellow'
    $confirm = Read-Host "`nContinue with Enforce mode? (yes/no)"
    if ($confirm -ne 'yes') {
        Write-ColorOutput "Deployment cancelled" 'Yellow'
        exit 0
    }
}

# Deploy policies
$startTime = Get-Date

if ($Category -eq 'all') {
    foreach ($cat in $policyDirs.Keys) {
        Deploy-Policies -Directory $policyDirs[$cat] -CategoryName $cat
    }
} else {
    Deploy-Policies -Directory $policyDirs[$Category] -CategoryName $Category
}

$duration = (Get-Date) - $startTime

# Summary
Write-ColorOutput "`n" 'White'
Write-ColorOutput "═══════════════════════════════════════════════════════════" 'Cyan'
Write-ColorOutput "Deployment completed in $($duration.TotalSeconds) seconds" 'Green'

if (-not $DryRun) {
    Write-ColorOutput "`nNext steps:" 'Cyan'
    Write-ColorOutput "  1. Check policy status:" 'White'
    Write-ColorOutput "     kubectl get clusterpolicies" 'Gray'
    Write-ColorOutput "`n  2. Monitor policy reports:" 'White'
    Write-ColorOutput "     kubectl get policyreports -A" 'Gray'
    Write-ColorOutput "`n  3. View violations:" 'White'
    Write-ColorOutput '     kubectl get policyreport -A -o json | jq ''.items[].results[] | select(.result=="fail")''' 'Gray'
    
    if ($Mode -eq 'Audit') {
        Write-ColorOutput "`n  4. After testing, switch to Enforce mode:" 'White'
        Write-ColorOutput "     .\deploy.ps1 -Mode Enforce" 'Gray'
    }
}

Write-ColorOutput "═══════════════════════════════════════════════════════════" 'Cyan'
