#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install Argo Events - Event-driven workflow automation

.DESCRIPTION
    Installs Argo Events for event-based triggers and workflow automation.
    Integrates with ArgoCD and Argo Workflows.

.PARAMETER Version
    Argo Events version (default: v1.9.0)

.PARAMETER Namespace
    Namespace for Argo Events (default: argo-events)

.EXAMPLE
    .\install-argo-events.ps1
    # Install with defaults

.EXAMPLE
    .\install-argo-events.ps1 -Version v1.8.0
#>

param(
    [string]$Version = "",
    [string]$Namespace = "argo-events"
)

$ErrorActionPreference = "Stop"

# Load versions from central configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VersionsFile = Join-Path $ScriptDir "versions.psd1"
if (Test-Path $VersionsFile) {
    $Versions = Import-PowerShellDataFile -Path $VersionsFile
    if (-not $Version) {
        $Version = $Versions.ArgoEvents
    }
} elseif (-not $Version) {
    $Version = "2.4.3"  # Fallback default
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Installing Argo Events" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Version:   $Version" -ForegroundColor Yellow
Write-Host "Namespace: $Namespace" -ForegroundColor Yellow
Write-Host ""

# Create namespace
Write-Host "Creating namespace: $Namespace" -ForegroundColor Green
kubectl create namespace $Namespace 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Namespace already exists" -ForegroundColor Yellow
}

# Add Argo Helm repository
Write-Host "Adding Argo Helm repository..." -ForegroundColor Green
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install Argo Events using Helm
Write-Host "Installing Argo Events via Helm..." -ForegroundColor Green
helm install argo-events argo/argo-events `
    --namespace $Namespace `
    --create-namespace `
    --version $Version `
    --wait

if ($LASTEXITCODE -ne 0) {
    Write-Error "Argo Events installation failed"
    exit 1
}

# Create default EventBus
Write-Host ""
Write-Host "Creating default EventBus..." -ForegroundColor Green
$EventBus = @"
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: $Namespace
spec:
  nats:
    native:
      replicas: 3
"@

$EventBus | kubectl apply -f -

# Wait for EventBus
Write-Host "Waiting for EventBus to be ready..." -ForegroundColor Green
Start-Sleep -Seconds 10
kubectl wait --for=condition=Ready eventbus/default -n $Namespace --timeout=180s 2>$null

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Argo Events installed successfully!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Argo Events components:" -ForegroundColor Cyan
kubectl get pods -n $Namespace
Write-Host ""
Write-Host "EventBus status:" -ForegroundColor Cyan
kubectl get eventbus -n $Namespace
Write-Host ""
Write-Host "Argo Events CRDs:" -ForegroundColor Cyan
kubectl get crds | Select-String "argoproj.io"
Write-Host ""
Write-Host "Example components:" -ForegroundColor Cyan
Write-Host "  Event Sources: webhook, calendar, resource, kafka, aws-sns, etc." -ForegroundColor White
Write-Host "  Sensors: Trigger actions based on events" -ForegroundColor White
Write-Host "  Triggers: Kubernetes resources, Argo Workflows, HTTP requests" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Create EventSource: kubectl apply -f eventsource.yaml" -ForegroundColor White
Write-Host "  2. Create Sensor: kubectl apply -f sensor.yaml" -ForegroundColor White
Write-Host ""
Write-Host "Documentation:" -ForegroundColor Cyan
Write-Host "  https://argoproj.github.io/argo-events/" -ForegroundColor White
