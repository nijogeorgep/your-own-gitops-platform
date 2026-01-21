#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Render cw-service chart templates locally

.DESCRIPTION
    Renders Helm templates to YAML without deploying to cluster.
    Useful for validation, debugging, and GitOps workflows.

.PARAMETER ReleaseName
    Name of the Helm release (default: nginx)

.PARAMETER ValuesFile
    Path to values file (default: nginx-dev-values.yaml)

.PARAMETER OutputFile
    Output file path (default: stdout)

.PARAMETER Debug
    Show detailed template rendering information

.EXAMPLE
    .\template.ps1
    # Render templates to console

.EXAMPLE
    .\template.ps1 -OutputFile nginx-manifests.yaml
    # Save rendered templates to file

.EXAMPLE
    .\template.ps1 -ValuesFile nginx-prod-values.yaml -Debug
    # Render production templates with debug info
#>

param(
    [string]$ReleaseName = "nginx",
    [string]$ValuesFile = "nginx-dev-values.yaml",
    [string]$OutputFile = "",
    [switch]$Debug
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
Write-Host "Rendering cw-service Chart Templates" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Release Name: $ReleaseName" -ForegroundColor Yellow
Write-Host "Values File:  $ValuesFile" -ForegroundColor Yellow
if ($OutputFile) {
    Write-Host "Output File:  $OutputFile" -ForegroundColor Yellow
}
Write-Host ""

# Update helm dependencies
Write-Host "Updating Helm dependencies..." -ForegroundColor Green
Push-Location $ChartPath
helm dependency update 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Error "Failed to update dependencies"
    exit 1
}
Pop-Location

# Build helm template command
$HelmArgs = @(
    "template", $ReleaseName, $ChartPath,
    "--values", $ValuesPath
)

if ($Debug) {
    $HelmArgs += "--debug"
}

Write-Host "Rendering templates..." -ForegroundColor Green

# Execute helm template
if ($OutputFile) {
    & helm $HelmArgs | Out-File -FilePath $OutputFile -Encoding utf8
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Templates saved to: $OutputFile" -ForegroundColor Green
        
        # Show summary
        $Content = Get-Content $OutputFile -Raw
        $ResourceCount = ($Content | Select-String "^kind:" -AllMatches).Matches.Count
        Write-Host "Resources rendered: $ResourceCount" -ForegroundColor Cyan
    }
} else {
    & helm $HelmArgs
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Template rendering failed!"
    exit 1
}
