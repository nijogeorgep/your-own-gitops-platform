#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generate Kargo resources for services in the GitOps platform.

.DESCRIPTION
    Scans the services/ directory and generates Kargo Project, Warehouse, and Stage
    resources for each service. Each service gets its own isolated Kargo namespace
    (kargo-<service-name>) for better RBAC, blast radius isolation, and scalability.

.PARAMETER ServiceName
    Generate resources for a specific service. If not specified, generates for all services.

.PARAMETER ImageRepository
    Base image repository URL (default: your-registry.io)

.PARAMETER GitRepoURL
    Git repository URL (default: https://github.com/YOUR_ORG/gitops-platform.git)

.PARAMETER Region
    Default region for stages (default: us-east-1)

.PARAMETER Force
    Overwrite existing generated files without prompting

.EXAMPLE
    .\generate-kargo-resources.ps1
    Generate Kargo resources for all services

.EXAMPLE
    .\generate-kargo-resources.ps1 -ServiceName nginx
    Generate resources only for nginx service

.EXAMPLE
    .\generate-kargo-resources.ps1 -ImageRepository myregistry.io -GitRepoURL https://github.com/myorg/repo.git
    Generate with custom repository URLs
#>

param(
    [Parameter(Position = 0)]
    [string]$ServiceName = "all",
    
    [Parameter()]
    [string]$ImageRepository = "your-registry.io",
    
    [Parameter()]
    [string]$GitRepoURL = "https://github.com/YOUR_ORG/gitops-platform.git",
    
    [Parameter()]
    [string]$Region = "us-east-1",
    
    [Parameter()]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Paths
$scriptDir = $PSScriptRoot
$servicesDir = Join-Path $scriptDir ".." "services"
$templatesDir = Join-Path $scriptDir "templates"
$projectsDir = Join-Path $scriptDir "projects"

# Ensure directories exist
if (-not (Test-Path $servicesDir)) {
    Write-Error "Services directory not found: $servicesDir"
    exit 1
}

if (-not (Test-Path $templatesDir)) {
    Write-Error "Templates directory not found: $templatesDir"
    exit 1
}

# Create projects directory if it doesn't exist
if (-not (Test-Path $projectsDir)) {
    New-Item -ItemType Directory -Path $projectsDir | Out-Null
    Write-Host "Created projects directory: $projectsDir" -ForegroundColor Green
}

# Get list of services
if ($ServiceName -eq "all") {
    $services = Get-ChildItem -Path $servicesDir -Directory | Where-Object { $_.Name -ne "SERVICE-TEMPLATE.md" }
    Write-Host "Generating Kargo resources for all services..." -ForegroundColor Cyan
} else {
    $servicePath = Join-Path $servicesDir $ServiceName
    if (-not (Test-Path $servicePath)) {
        Write-Error "Service not found: $ServiceName"
        exit 1
    }
    $services = @(Get-Item $servicePath)
    Write-Host "Generating Kargo resources for service: $ServiceName" -ForegroundColor Cyan
}

# Function to replace template placeholders
function Expand-Template {
    param(
        [string]$TemplatePath,
        [hashtable]$Replacements
    )
    
    $content = Get-Content -Path $TemplatePath -Raw
    
    foreach ($key in $Replacements.Keys) {
        $content = $content -replace [regex]::Escape("{{$key}}"), $Replacements[$key]
    }
    
    return $content
}

# Generate resources for each service
$successCount = 0
$failCount = 0

foreach ($service in $services) {
    $name = $service.Name
    Write-Host "`nProcessing service: $name" -ForegroundColor Yellow
    
    # Create service project directory
    $serviceProjectDir = Join-Path $projectsDir $name
    if (Test-Path $serviceProjectDir) {
        if (-not $Force) {
            $response = Read-Host "Directory already exists for $name. Overwrite? (y/N)"
            if ($response -ne 'y' -and $response -ne 'Y') {
                Write-Host "  Skipped $name" -ForegroundColor Gray
                continue
            }
        }
        Remove-Item -Path $serviceProjectDir -Recurse -Force
    }
    
    New-Item -ItemType Directory -Path $serviceProjectDir | Out-Null
    
    try {
        # Template replacements
        $replacements = @{
            SERVICE_NAME = $name
            IMAGE_REPOSITORY = "$ImageRepository/$name"
            GIT_REPO_URL = $GitRepoURL
            REGION = $Region
        }
        
        # Generate namespace.yaml
        $namespaceTemplate = Join-Path $templatesDir "namespace.yaml.template"
        $namespaceContent = Expand-Template -TemplatePath $namespaceTemplate -Replacements $replacements
        $namespaceContent | Out-File -FilePath (Join-Path $serviceProjectDir "namespace.yaml") -Encoding utf8
        Write-Host "  ✓ Generated namespace.yaml" -ForegroundColor Green
        
        # Generate project.yaml
        $projectTemplate = Join-Path $templatesDir "project.yaml.template"
        $projectContent = Expand-Template -TemplatePath $projectTemplate -Replacements $replacements
        $projectContent | Out-File -FilePath (Join-Path $serviceProjectDir "project.yaml") -Encoding utf8
        Write-Host "  ✓ Generated project.yaml" -ForegroundColor Green
        
        # Generate warehouse.yaml
        $warehouseTemplate = Join-Path $templatesDir "warehouse.yaml.template"
        $warehouseContent = Expand-Template -TemplatePath $warehouseTemplate -Replacements $replacements
        $warehouseContent | Out-File -FilePath (Join-Path $serviceProjectDir "warehouse.yaml") -Encoding utf8
        Write-Host "  ✓ Generated warehouse.yaml" -ForegroundColor Green
        
        # Generate stages.yaml
        $stagesTemplate = Join-Path $templatesDir "stages.yaml.template"
        $stagesContent = Expand-Template -TemplatePath $stagesTemplate -Replacements $replacements
        $stagesContent | Out-File -FilePath (Join-Path $serviceProjectDir "stages.yaml") -Encoding utf8
        Write-Host "  ✓ Generated stages.yaml" -ForegroundColor Green
        
        $successCount++
    } catch {
        Write-Host "  ✗ Failed to generate resources for $name : $_" -ForegroundColor Red
        $failCount++
    }
}

# Summary
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "Generation Summary:" -ForegroundColor Cyan
Write-Host "  ✓ Successfully generated: $successCount service(s)" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "  ✗ Failed: $failCount service(s)" -ForegroundColor Red
}
Write-Host "="*60 -ForegroundColor Cyan

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Review generated files in: $projectsDir" -ForegroundColor White
Write-Host "  2. Update Git repository URL and image registry if needed" -ForegroundColor White
Write-Host "  3. Deploy resources: .\deploy.ps1" -ForegroundColor White
Write-Host "  4. Verify in Kargo UI: http://localhost:8080/kargo" -ForegroundColor White
