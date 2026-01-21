# Platform Gateway Configuration

Istio Gateway and VirtualServices for exposing platform UIs through a single LoadBalancer.

## Components Exposed

- **ArgoCD**: `/argocd` - GitOps continuous delivery UI
- **Headlamp**: `/headlamp` - Kubernetes cluster management UI
- **Kargo**: `/kargo` - Promotion workflow UI
- **Argo Rollouts**: `/rollouts` - Progressive delivery dashboard

## Prerequisites

- Istio must be installed with ingress gateway
- All UI components must be installed in their respective namespaces

## Quick Start

### Apply All Configurations
```powershell
.\apply.ps1
```

### For Docker Desktop / Kind / Minikube

**Option 1: Background Job (Recommended)**
```powershell
.\start-gateway.ps1
# Keeps running in background, survives terminal close
```

**Option 2: Foreground (Simple)**
```powershell
.\port-forward.ps1
# Keep terminal open while accessing UIs
```

**Option 3: Manual**
```powershell
kubectl port-forward -n istio-ingress svc/istio-ingress 8080:80
```

Then access via `http://localhost:8080/argocd`, `/headlamp`, `/rollouts`

### For Cloud Clusters (EKS, GKE, AKS)
```powershell
# Apply gateway
kubectl apply -f gateway.yaml

# Apply VirtualServices
kubectl apply -f argocd-virtualservice.yaml
kubectl apply -f headlamp-virtualservice.yaml
kubectl apply -f kargo-virtualservice.yaml
kubectl apply -f rollouts-virtualservice.yaml
```

### Configure ArgoCD for Path Prefix
```powershell
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.basehref":"/argocd","server.rootpath":"/argocd"}}'
kubectl rollout restart deployment argocd-server -n argocd
```

## Access UIs

Get the gateway external IP:
```powershell
kubectl get svc istio-ingress -n istio-ingress
```

Access URLs:
- ArgoCD: `http://<EXTERNAL-IP>/argocd`
- Headlamp: `http://<EXTERNAL-IP>/headlamp`
- Kargo: `http://<EXTERNAL-IP>/kargo`
- Rollouts: `http://<EXTERNAL-IP>/rollouts`

### For Local Clusters (Docker Desktop / Kind / Minikube)

If using Docker Desktop with Kind or minikube without LoadBalancer support, use the port-forward helper script:

```powershell
.\port-forward.ps1
```

Or manually:
```powershell
kubectl port-forward -n istio-ingress svc/istio-ingress 8080:80
```

Then access via:
- **ArgoCD**: `http://localhost:8080/argocd`
- **Headlamp**: `http://localhost:8080/headlamp`
- **Kargo**: `http://localhost:8080/kargo`
- **Rollouts**: `http://localhost:8080/rollouts`

**Benefits:**
- ✅ Single port-forward for all UIs (instead of one per service)
- ✅ Path-based routing works exactly the same as production
- ✅ Easy to script and automate

## Verify Installation

```powershell
# Check Gateway
kubectl get gateway -n istio-system

# Check VirtualServices
kubectl get virtualservices -A

# Check Gateway service
kubectl get svc istio-ingress -n istio-ingress

# Check Gateway logs
kubectl logs -n istio-ingress -l app=istio-ingressgateway
```

## Troubleshooting

### ArgoCD Not Loading
Ensure ArgoCD is configured for path-based routing:
```powershell
kubectl get configmap argocd-cmd-params-cm -n argocd -o yaml
```
Should contain `server.basehref: /argocd` and `server.rootpath: /argocd`

### 404 Errors
Check VirtualService routing:
```powershell
kubectl describe virtualservice <name> -n <namespace>
```

### Gateway Not Getting External IP
For local development, use port-forwarding or install MetalLB:
```powershell
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
```

## HTTPS Configuration

To enable HTTPS, create a TLS certificate and update the gateway:

```yaml
# In gateway.yaml, add HTTPS server
- port:
    number: 443
    name: https
    protocol: HTTPS
  tls:
    mode: SIMPLE
    credentialName: platform-tls-cert
  hosts:
  - "platform.example.com"
```

Create certificate with cert-manager:
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: platform-tls-cert
  namespace: istio-system
spec:
  secretName: platform-tls-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - platform.example.com
```

## Clean Up

```powershell
kubectl delete -f .
```
