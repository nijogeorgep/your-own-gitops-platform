# Deploy ApplicationSet GitOps Strategy
# This script applies the App of Apps pattern to bootstrap ArgoCD with ApplicationSet

param(
    [string]$GitRepoUrl = "",
    [switch]$DryRun
)

Write-Host "ArgoCD ApplicationSet Deployment Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Git repo URL is provided
if ([string]::IsNullOrWhiteSpace($GitRepoUrl)) {
    Write-Host "WARNING: Git repository URL not provided" -ForegroundColor Yellow
    Write-Host "You need to update the following files with your Git repository URL:" -ForegroundColor Yellow
    Write-Host "  - argocd-bootstrap/applicationset-services.yaml" -ForegroundColor Yellow
    Write-Host "  - argocd-bootstrap/app-of-apps.yaml" -ForegroundColor Yellow
    Write-Host ""
    $GitRepoUrl = Read-Host "Enter your Git repository URL (e.g., https://github.com/yourorg/gitops-platform.git)"
}

if ([string]::IsNullOrWhiteSpace($GitRepoUrl)) {
    Write-Host "ERROR: Git repository URL is required" -ForegroundColor Red
    exit 1
}

Write-Host "Using Git repository: $GitRepoUrl" -ForegroundColor Green
Write-Host ""

# Update Git URLs in files
$bootstrapDir = Join-Path $PSScriptRoot ".." "argocd-bootstrap"
$applicationSetFile = Join-Path $bootstrapDir "applicationset-services.yaml"
$appOfAppsFile = Join-Path $bootstrapDir "app-of-apps.yaml"

if (-not $DryRun) {
    Write-Host "Updating Git repository URLs in manifest files..." -ForegroundColor Cyan
    
    # Update ApplicationSet
    if (Test-Path $applicationSetFile) {
        $content = Get-Content $applicationSetFile -Raw
        $content = $content -replace 'https://github.com/YOUR_ORG/gitops-platform\.git', $GitRepoUrl
        Set-Content $applicationSetFile -Value $content -NoNewline
        Write-Host "  ✓ Updated applicationset-services.yaml" -ForegroundColor Green
    }
    
    # Update App of Apps
    if (Test-Path $appOfAppsFile) {
        $content = Get-Content $appOfAppsFile -Raw
        $content = $content -replace 'https://github.com/YOUR_ORG/gitops-platform\.git', $GitRepoUrl
        Set-Content $appOfAppsFile -Value $content -NoNewline
        Write-Host "  ✓ Updated app-of-apps.yaml" -ForegroundColor Green
    }
    Write-Host ""
}

# Check if ArgoCD is installed
Write-Host "Checking ArgoCD installation..." -ForegroundColor Cyan
$argocdPods = kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o json 2>$null | ConvertFrom-Json

if ($null -eq $argocdPods -or $argocdPods.items.Count -eq 0) {
    Write-Host "ERROR: ArgoCD is not installed or not running" -ForegroundColor Red
    Write-Host "Please install ArgoCD first using: .\cw-tools\install-argocd.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "  ✓ ArgoCD is running" -ForegroundColor Green
Write-Host ""

# Check service directory structure
Write-Host "Validating service directory structure..." -ForegroundColor Cyan
$servicesDir = Join-Path $PSScriptRoot ".." "services"

if (-not (Test-Path $servicesDir)) {
    Write-Host "ERROR: services/ directory not found" -ForegroundColor Red
    exit 1
}

$serviceDirectories = Get-ChildItem -Path $servicesDir -Directory
Write-Host "  Found $($serviceDirectories.Count) service(s):" -ForegroundColor Green

foreach ($service in $serviceDirectories) {
    Write-Host "    - $($service.Name)" -ForegroundColor White
    
    # Check for required values files
    $requiredFiles = @("base-values.yaml", "values-dev.yaml", "values-staging.yaml", "values-prod.yaml")
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $service.FullName $file
        if (-not (Test-Path $filePath)) {
            Write-Host "      WARNING: Missing $file" -ForegroundColor Yellow
        }
    }
}
Write-Host ""

# Display deployment plan
Write-Host "Deployment Plan:" -ForegroundColor Cyan
Write-Host "  1. Create bootstrap Application (App of Apps)" -ForegroundColor White
Write-Host "  2. Bootstrap Application deploys ApplicationSet" -ForegroundColor White
Write-Host "  3. ApplicationSet auto-generates Applications:" -ForegroundColor White

foreach ($service in $serviceDirectories) {
    Write-Host "       - $($service.Name)-dev" -ForegroundColor Gray
    Write-Host "       - $($service.Name)-staging" -ForegroundColor Gray
    Write-Host "       - $($service.Name)-prod" -ForegroundColor Gray
}
Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN MODE - Would execute:" -ForegroundColor Yellow
    Write-Host "  kubectl apply -f $appOfAppsFile" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To actually deploy, run without -DryRun flag" -ForegroundColor Yellow
    exit 0
}

# Confirm deployment
Write-Host "Ready to deploy ApplicationSet GitOps strategy" -ForegroundColor Yellow
$confirm = Read-Host "Continue? (y/n)"

if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "Deployment cancelled" -ForegroundColor Yellow
    exit 0
}
Write-Host ""

# Deploy App of Apps
Write-Host "Deploying bootstrap Application..." -ForegroundColor Cyan
kubectl apply -f $appOfAppsFile

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to deploy bootstrap Application" -ForegroundColor Red
    exit 1
}

Write-Host "  ✓ Bootstrap Application created" -ForegroundColor Green
Write-Host ""

# Wait for ApplicationSet to be created
Write-Host "Waiting for ApplicationSet to be created (max 60s)..." -ForegroundColor Cyan
$timeout = 60
$elapsed = 0

while ($elapsed -lt $timeout) {
    $appSet = kubectl get applicationset platform-services -n argocd -o json 2>$null | ConvertFrom-Json
    if ($null -ne $appSet) {
        Write-Host "  ✓ ApplicationSet 'platform-services' created" -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 3
    $elapsed += 3
    Write-Host "  Waiting... ($elapsed/$timeout seconds)" -ForegroundColor Gray
}

if ($elapsed -ge $timeout) {
    Write-Host "  WARNING: Timeout waiting for ApplicationSet" -ForegroundColor Yellow
    Write-Host "  Check ArgoCD logs: kubectl logs -n argocd deploy/argocd-application-controller" -ForegroundColor Yellow
}
Write-Host ""

# Wait for Applications to be generated
Write-Host "Waiting for Applications to be generated (max 180s)..." -ForegroundColor Cyan
Write-Host "  (ApplicationSet refresh interval is 3 minutes)" -ForegroundColor Gray

$timeout = 180
$elapsed = 0
$expectedApps = $serviceDirectories.Count * 3  # 3 environments per service

while ($elapsed -lt $timeout) {
    $apps = kubectl get applications -n argocd -l managed-by=applicationset -o json 2>$null | ConvertFrom-Json
    $appCount = if ($null -ne $apps -and $null -ne $apps.items) { $apps.items.Count } else { 0 }
    
    if ($appCount -ge $expectedApps) {
        Write-Host "  ✓ All $appCount Applications generated" -ForegroundColor Green
        break
    }
    
    Start-Sleep -Seconds 10
    $elapsed += 10
    Write-Host "  Generated $appCount/$expectedApps Applications ($elapsed/$timeout seconds)" -ForegroundColor Gray
}

if ($elapsed -ge $timeout) {
    Write-Host "  WARNING: Not all Applications generated yet" -ForegroundColor Yellow
    Write-Host "  This may take up to 3 minutes for ApplicationSet refresh" -ForegroundColor Yellow
}
Write-Host ""

# Display created Applications
Write-Host "Generated Applications:" -ForegroundColor Cyan
kubectl get applications -n argocd -l managed-by=applicationset -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
Write-Host ""

# Deployment summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. View Applications in ArgoCD UI:" -ForegroundColor White
Write-Host "     kubectl port-forward svc/argocd-server -n argocd 8080:443" -ForegroundColor Gray
Write-Host "     https://localhost:8080/argocd" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Check Application status:" -ForegroundColor White
Write-Host "     kubectl get applications -n argocd -l managed-by=applicationset" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Sync applications (if not auto-synced):" -ForegroundColor White
Write-Host "     argocd app sync <app-name>" -ForegroundColor Gray
Write-Host ""
Write-Host "  4. Add new services by creating directories in services/" -ForegroundColor White
Write-Host "     See: services/SERVICE-TEMPLATE.md" -ForegroundColor Gray
Write-Host ""
Write-Host "Documentation: argocd-bootstrap/README.md" -ForegroundColor Cyan
