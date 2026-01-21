# GitOps Platform - Tool Versions
# This file maintains all version numbers for platform components
# Update versions here to upgrade components across all installation scripts

@{
    # Certificate Management
    CertManager = "v1.19.2"
    
    # Service Mesh
    Istio = "1.28.3"
    
    # GitOps & Continuous Delivery
    ArgoCD = "9.3.4"  # Helm chart version
    
    # Progressive Delivery
    ArgoRollouts = "2.40.5"  # Helm chart version
    
    # Event-Driven Automation
    ArgoEvents = "2.4.19"  # Helm chart version
    
    # Promotion Workflows
    Kargo = "1.8.6"  # Chart version without 'v' prefix
    
    # Policy Engine
    Kyverno = "3.1.4"  # Helm chart version
    
    # Kubernetes UI
    KubernetesDashboard = "7.11.0"  # Helm chart version
    
    # Helm Repositories
    Repositories = @{
        Jetstack = "https://charts.jetstack.io"
        Istio = "https://istio-release.storage.googleapis.com/charts"
        Argo = "https://argoproj.github.io/argo-helm"
        KargoOCI = "oci://ghcr.io/akuity/kargo-charts/kargo"
        KubernetesDashboard = "https://kubernetes.github.io/dashboard/"
    }
}
