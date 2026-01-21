#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install cert-manager with Let's Encrypt support

.DESCRIPTION
    Installs cert-manager for automated TLS certificate management.
    Configures ClusterIssuers for Let's Encrypt staging and production.

.PARAMETER Version
    cert-manager version (default: v1.14.1)

.PARAMETER Namespace
    Namespace for cert-manager (default: cert-manager)

.PARAMETER Email
    Email for Let's Encrypt registration (required for production)

.PARAMETER ConfigureLetsEncrypt
    Create Let's Encrypt ClusterIssuers (default: true)

.EXAMPLE
    .\install-cert-manager.ps1 -Email admin@example.com
    # Install with Let's Encrypt configured

.EXAMPLE
    .\install-cert-manager.ps1 -ConfigureLetsEncrypt $false
    # Install without Let's Encrypt setup
#>

param(
    [string]$Version = "",
    [string]$Namespace = "cert-manager",
    [string]$Email = "",
    [bool]$ConfigureLetsEncrypt = $true
)

$ErrorActionPreference = "Stop"

# Load versions from central configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VersionsFile = Join-Path $ScriptDir "versions.psd1"
if (Test-Path $VersionsFile) {
    $Versions = Import-PowerShellDataFile -Path $VersionsFile
    if (-not $Version) {
        $Version = $Versions.CertManager
    }
} elseif (-not $Version) {
    $Version = "v1.14.1"  # Fallback default
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Installing cert-manager" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Version:   $Version" -ForegroundColor Yellow
Write-Host "Namespace: $Namespace" -ForegroundColor Yellow
Write-Host ""

if ($ConfigureLetsEncrypt -and -not $Email) {
    Write-Warning "Email not provided. Let's Encrypt requires a valid email."
    Write-Host "Provide email with: -Email admin@example.com" -ForegroundColor Yellow
    $ConfigureLetsEncrypt = $false
}

# Add Jetstack Helm repository
Write-Host "Adding Jetstack Helm repository..." -ForegroundColor Green
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager using Helm
Write-Host "Installing cert-manager via Helm..." -ForegroundColor Green
helm install cert-manager jetstack/cert-manager `
    --namespace $Namespace `
    --create-namespace `
    --version $Version `
    --set installCRDs=true `
    --wait

if ($LASTEXITCODE -ne 0) {
    Write-Error "cert-manager installation failed"
    exit 1
}

# Configure Let's Encrypt if requested
if ($ConfigureLetsEncrypt) {
    Write-Host ""
    Write-Host "Configuring Let's Encrypt ClusterIssuers..." -ForegroundColor Green
    
    # Let's Encrypt Staging ClusterIssuer
    $StagingIssuer = @"
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: $Email
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
"@
    
    # Let's Encrypt Production ClusterIssuer
    $ProductionIssuer = @"
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $Email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
"@
    
    # Apply ClusterIssuers
    $StagingIssuer | kubectl apply -f -
    $ProductionIssuer | kubectl apply -f -
    
    Write-Host "Let's Encrypt ClusterIssuers created" -ForegroundColor Green
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "cert-manager installed successfully!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "cert-manager components:" -ForegroundColor Cyan
kubectl get pods -n $Namespace
Write-Host ""

if ($ConfigureLetsEncrypt) {
    Write-Host "Let's Encrypt ClusterIssuers:" -ForegroundColor Cyan
    kubectl get clusterissuers
    Write-Host ""
    Write-Host "Use in Ingress annotations:" -ForegroundColor Cyan
    Write-Host "  # Staging (for testing)" -ForegroundColor Yellow
    Write-Host "  cert-manager.io/cluster-issuer: letsencrypt-staging" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Production (rate limited)" -ForegroundColor Yellow
    Write-Host "  cert-manager.io/cluster-issuer: letsencrypt-prod" -ForegroundColor White
    Write-Host ""
}

Write-Host "Example Certificate:" -ForegroundColor Cyan
Write-Host @"
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-com-tls
  namespace: default
spec:
  secretName: example-com-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - example.com
  - www.example.com
"@ -ForegroundColor White
Write-Host ""
Write-Host "Check certificates:" -ForegroundColor Cyan
Write-Host "  kubectl get certificates --all-namespaces" -ForegroundColor White
Write-Host "  kubectl describe certificate <name> -n <namespace>" -ForegroundColor White
