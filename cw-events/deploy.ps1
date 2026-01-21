# Deploy Argo Events + Workflows Integration
# This script sets up the complete CI/CD pipeline integration

param(
    [string]$GitRepoUrl = "",
    [string]$GitHubOrg = "",
    [string]$GitHubRepo = "",
    [string]$ContainerRegistry = "",
    [switch]$SkipSecrets,
    [switch]$DryRun
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Argo Events + Workflows Integration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Validate parameters
if ([string]::IsNullOrWhiteSpace($GitRepoUrl)) {
    Write-Host "Git repository URL is required" -ForegroundColor Yellow
    $GitRepoUrl = Read-Host "Enter Git repository URL (e.g., https://github.com/yourorg/gitops-platform.git)"
}

if ([string]::IsNullOrWhiteSpace($GitHubOrg)) {
    # Extract from Git URL
    if ($GitRepoUrl -match 'github\.com[:/]([^/]+)/([^/\.]+)') {
        $GitHubOrg = $matches[1]
        $GitHubRepo = $matches[2]
    } else {
        $GitHubOrg = Read-Host "Enter GitHub organization/username"
        $GitHubRepo = Read-Host "Enter GitHub repository name"
    }
}

if ([string]::IsNullOrWhiteSpace($ContainerRegistry)) {
    Write-Host "Container registry examples:" -ForegroundColor Gray
    Write-Host "  - docker.io/youruser" -ForegroundColor Gray
    Write-Host "  - ghcr.io/yourorg" -ForegroundColor Gray
    Write-Host "  - quay.io/yourorg" -ForegroundColor Gray
    $ContainerRegistry = Read-Host "Enter container registry"
}

Write-Host "Configuration:" -ForegroundColor Green
Write-Host "  Git Repo:     $GitRepoUrl" -ForegroundColor White
Write-Host "  GitHub Org:   $GitHubOrg" -ForegroundColor White
Write-Host "  GitHub Repo:  $GitHubRepo" -ForegroundColor White
Write-Host "  Registry:     $ContainerRegistry" -ForegroundColor White
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Cyan

$missingPrereqs = @()

# Check Argo Events
$argoEventsPods = kubectl get pods -n argo-events -l app.kubernetes.io/part-of=argo-events -o json 2>$null | ConvertFrom-Json
if ($null -eq $argoEventsPods -or $argoEventsPods.items.Count -eq 0) {
    $missingPrereqs += "Argo Events"
}

# Check Argo Workflows
$argoWorkflowsPods = kubectl get pods -n argo-workflows -l app.kubernetes.io/name=argo-workflows-server -o json 2>$null | ConvertFrom-Json
if ($null -eq $argoWorkflowsPods -or $argoWorkflowsPods.items.Count -eq 0) {
    Write-Host "  ⚠ Argo Workflows not found, will install..." -ForegroundColor Yellow
    
    if (-not $DryRun) {
        kubectl create namespace argo-workflows --dry-run=client -o yaml | kubectl apply -f -
        kubectl apply -n argo-workflows -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.4/install.yaml
        
        Write-Host "  Waiting for Argo Workflows to be ready..." -ForegroundColor Gray
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argo-workflows-server -n argo-workflows --timeout=120s
    }
}

# Check ArgoCD
$argocdPods = kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o json 2>$null | ConvertFrom-Json
if ($null -eq $argocdPods -or $argocdPods.items.Count -eq 0) {
    $missingPrereqs += "ArgoCD"
}

if ($missingPrereqs.Count -gt 0) {
    Write-Host "ERROR: Missing prerequisites: $($missingPrereqs -join ', ')" -ForegroundColor Red
    Write-Host "Please install missing components first" -ForegroundColor Yellow
    exit 1
}

Write-Host "  ✓ All prerequisites satisfied" -ForegroundColor Green
Write-Host ""

# Create secrets
if (-not $SkipSecrets) {
    Write-Host "Setting up secrets..." -ForegroundColor Cyan
    
    # GitHub Access Token
    Write-Host "  GitHub Access Token (for webhook and Git operations)" -ForegroundColor Yellow
    Write-Host "    Create at: https://github.com/settings/tokens" -ForegroundColor Gray
    Write-Host "    Required scopes: repo (full)" -ForegroundColor Gray
    $githubToken = Read-Host "  Enter GitHub Personal Access Token" -AsSecureString
    $githubTokenPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($githubToken))
    
    if (-not $DryRun) {
        # GitHub access for Events
        kubectl create secret generic github-access -n argo-events `
            --from-literal=token=$githubTokenPlain `
            --dry-run=client -o yaml | kubectl apply -f -
        
        # Git credentials for Workflows
        kubectl create secret generic git-credentials -n argo-workflows `
            --from-literal=token=$githubTokenPlain `
            --dry-run=client -o yaml | kubectl apply -f -
        
        Write-Host "    ✓ GitHub token configured" -ForegroundColor Green
    }
    
    # Webhook Secret
    Write-Host "  GitHub Webhook Secret" -ForegroundColor Yellow
    $webhookSecret = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
    
    if (-not $DryRun) {
        kubectl create secret generic github-webhook-secret -n argo-events `
            --from-literal=secret=$webhookSecret `
            --dry-run=client -o yaml | kubectl apply -f -
        
        Write-Host "    ✓ Webhook secret: $webhookSecret" -ForegroundColor Green
        Write-Host "      (Save this for GitHub webhook configuration)" -ForegroundColor Gray
    }
    
    # Container Registry Credentials
    Write-Host "  Container Registry Credentials" -ForegroundColor Yellow
    $registryUsername = Read-Host "  Registry username"
    $registryPassword = Read-Host "  Registry password/token" -AsSecureString
    $registryPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($registryPassword))
    
    $registryServer = $ContainerRegistry -replace '/.*$', ''
    
    if (-not $DryRun) {
        kubectl create secret docker-registry regcred -n argo-workflows `
            --docker-server=$registryServer `
            --docker-username=$registryUsername `
            --docker-password=$registryPasswordPlain `
            --dry-run=client -o yaml | kubectl apply -f -
        
        Write-Host "    ✓ Registry credentials configured" -ForegroundColor Green
    }
    Write-Host ""
}

# Update manifest files
Write-Host "Updating manifest files..." -ForegroundColor Cyan

$eventsDir = Join-Path $PSScriptRoot ".." "cw-events"
$workflowsDir = Join-Path $PSScriptRoot ".." "cw-workflows"

# Update EventSource
$eventSourceFile = Join-Path $eventsDir "eventsource-github.yaml"
if (Test-Path $eventSourceFile) {
    $content = Get-Content $eventSourceFile -Raw
    $content = $content -replace 'YOUR_GITHUB_ORG', $GitHubOrg
    $content = $content -replace 'repository: gitops-platform', "repository: $GitHubRepo"
    
    if (-not $DryRun) {
        Set-Content $eventSourceFile -Value $content -NoNewline
        Write-Host "  ✓ Updated eventsource-github.yaml" -ForegroundColor Green
    }
}

# Update WorkflowTemplates
$buildTemplate = Join-Path $workflowsDir "workflowtemplate-build-image.yaml"
if (Test-Path $buildTemplate) {
    $content = Get-Content $buildTemplate -Raw
    $content = $content -replace 'https://github.com/YOUR_ORG/gitops-platform\.git', $GitRepoUrl
    $content = $content -replace 'YOUR_REGISTRY', $ContainerRegistry
    
    if (-not $DryRun) {
        Set-Content $buildTemplate -Value $content -NoNewline
        Write-Host "  ✓ Updated workflowtemplate-build-image.yaml" -ForegroundColor Green
    }
}

$updateTemplate = Join-Path $workflowsDir "workflowtemplate-update-git.yaml"
if (Test-Path $updateTemplate) {
    $content = Get-Content $updateTemplate -Raw
    $content = $content -replace 'https://github.com/YOUR_ORG/gitops-platform\.git', $GitRepoUrl
    
    if (-not $DryRun) {
        Set-Content $updateTemplate -Value $content -NoNewline
        Write-Host "  ✓ Updated workflowtemplate-update-git.yaml" -ForegroundColor Green
    }
}

Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN MODE - Would deploy:" -ForegroundColor Yellow
    Write-Host "  - RBAC configuration" -ForegroundColor Gray
    Write-Host "  - EventSources (GitHub, Calendar)" -ForegroundColor Gray
    Write-Host "  - WorkflowTemplates (Build, Update Git)" -ForegroundColor Gray
    Write-Host "  - Sensors (Image Update Pipeline)" -ForegroundColor Gray
    exit 0
}

# Deploy RBAC
Write-Host "Deploying RBAC..." -ForegroundColor Cyan
kubectl apply -f (Join-Path $workflowsDir "rbac.yaml")
Write-Host "  ✓ RBAC configured" -ForegroundColor Green
Write-Host ""

# Deploy WorkflowTemplates
Write-Host "Deploying WorkflowTemplates..." -ForegroundColor Cyan
kubectl apply -f $buildTemplate
kubectl apply -f $updateTemplate
Write-Host "  ✓ WorkflowTemplates deployed" -ForegroundColor Green
Write-Host ""

# Deploy EventSources
Write-Host "Deploying EventSources..." -ForegroundColor Cyan
kubectl apply -f (Join-Path $eventsDir "eventsource-github.yaml")
kubectl apply -f (Join-Path $eventsDir "eventsource-calendar.yaml")

Write-Host "  Waiting for EventSources to be ready..." -ForegroundColor Gray
Start-Sleep -Seconds 10

$githubES = kubectl get eventsource github -n argo-events -o json 2>$null | ConvertFrom-Json
if ($null -ne $githubES) {
    Write-Host "  ✓ EventSources deployed" -ForegroundColor Green
}
Write-Host ""

# Deploy Sensors
Write-Host "Deploying Sensors..." -ForegroundColor Cyan
kubectl apply -f (Join-Path $eventsDir "sensor-image-update.yaml")

Write-Host "  Waiting for Sensors to be ready..." -ForegroundColor Gray
Start-Sleep -Seconds 10

$sensor = kubectl get sensor image-update-pipeline -n argo-events -o json 2>$null | ConvertFrom-Json
if ($null -ne $sensor) {
    Write-Host "  ✓ Sensors deployed" -ForegroundColor Green
}
Write-Host ""

# Deployment summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Deployed Components:" -ForegroundColor Yellow
Write-Host "  ✓ RBAC (ServiceAccounts, Roles, Bindings)" -ForegroundColor Green
Write-Host "  ✓ EventSources (GitHub webhooks, Calendar)" -ForegroundColor Green
Write-Host "  ✓ WorkflowTemplates (Build image, Update Git)" -ForegroundColor Green
Write-Host "  ✓ Sensors (Image update pipeline)" -ForegroundColor Green
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Configure GitHub Webhook:" -ForegroundColor White
Write-Host "   - Go to: https://github.com/$GitHubOrg/$GitHubRepo/settings/hooks" -ForegroundColor Gray
Write-Host "   - Add webhook" -ForegroundColor Gray
Write-Host "   - Payload URL: <your-domain>/webhooks/github (or use ngrok for testing)" -ForegroundColor Gray
Write-Host "   - Content type: application/json" -ForegroundColor Gray
Write-Host "   - Secret: $webhookSecret" -ForegroundColor Gray
Write-Host "   - Events: Push, Pull request, Release" -ForegroundColor Gray
Write-Host ""
Write-Host "2. For local testing, expose webhook endpoint:" -ForegroundColor White
Write-Host "   kubectl port-forward -n argo-events svc/github-eventsource-svc 12000:12000" -ForegroundColor Gray
Write-Host "   ngrok http 12000" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Add Dockerfile to your service:" -ForegroundColor White
Write-Host "   cd services/nginx" -ForegroundColor Gray
Write-Host "   # Create Dockerfile (see cw-events/README.md for example)" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Test the pipeline:" -ForegroundColor White
Write-Host "   # Make a change and push" -ForegroundColor Gray
Write-Host "   git add services/nginx/" -ForegroundColor Gray
Write-Host "   git commit -m 'test: trigger pipeline'" -ForegroundColor Gray
Write-Host "   git push origin main" -ForegroundColor Gray
Write-Host ""
Write-Host "5. Monitor workflows:" -ForegroundColor White
Write-Host "   kubectl get workflows -n argo-workflows --watch" -ForegroundColor Gray
Write-Host "   # Or use Argo Workflows UI:" -ForegroundColor Gray
Write-Host "   kubectl port-forward -n argo-workflows svc/argo-server 2746:2746" -ForegroundColor Gray
Write-Host "   # Open: https://localhost:2746" -ForegroundColor Gray
Write-Host ""

Write-Host "Documentation: cw-events/README.md" -ForegroundColor Cyan
Write-Host ""

# Display status
Write-Host "Current Status:" -ForegroundColor Yellow
Write-Host ""
Write-Host "EventSources:" -ForegroundColor White
kubectl get eventsource -n argo-events
Write-Host ""
Write-Host "Sensors:" -ForegroundColor White
kubectl get sensor -n argo-events
Write-Host ""
Write-Host "WorkflowTemplates:" -ForegroundColor White
kubectl get workflowtemplate -n argo-workflows
