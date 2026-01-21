# Argo Rollouts - Optional Progressive Delivery

Scalable pattern for enabling Argo Rollouts on a per-service, per-environment basis.

## Architecture Pattern

### Service-Level Opt-In (Recommended for Scale)
```
Each service decides independently:
- Dev environment: rollout.enabled = true (fast canary)
- Staging: rollout.enabled = true (moderate canary)
- Prod: rollout.enabled = true (slow canary) OR false (standard deployment)
```

### Mutual Exclusivity
```
rollout.enabled = false  →  Deployment template active
rollout.enabled = true   →  Rollout template active (Deployment disabled)
```

## Benefits of This Pattern

### ✅ **Scalability**
- Each of 1000+ services chooses independently
- No central coordination needed
- Works with existing ApplicationSet pattern
- Same cw-service chart for all services

### ✅ **Flexibility**
- Service A uses Rollout, Service B uses Deployment
- Different strategies per environment (fast dev, slow prod)
- Easy to migrate incrementally (enable one service at a time)

### ✅ **Zero Configuration Overhead**
- Default: `rollout.enabled: false` (standard Deployment)
- Opt-in: Add `rollout.enabled: true` to values file
- No additional manifests to maintain

## Quick Start

### 1. Enable Rollout for a Service

**In your service values file** (`services/myapp/values-prod.yaml`):
```yaml
# Add this block to enable progressive delivery
rollout:
  enabled: true
  strategy: canary
  canary:
    steps:
      - setWeight: 10
      - pause: {duration: 5m}
      - setWeight: 50
      - pause: {duration: 10m}
```

### 2. Deploy and Verify

```powershell
# Template to verify
cd cw-scripts/helm
.\template.ps1 -ValuesFile ..\..\services\myapp\values-prod.yaml

# Check for Rollout resource (not Deployment)
# Look for: kind: Rollout

# Deploy
.\install.ps1 -ReleaseName myapp-prod -ValuesFile ..\..\services\myapp\values-prod.yaml -Namespace prod
```

### 3. Monitor Rollout

```bash
# Watch rollout progress
kubectl argo rollouts get rollout myapp-prod -n prod --watch

# View rollout status
kubectl get rollout myapp-prod -n prod

# Manually promote (if paused)
kubectl argo rollouts promote myapp-prod -n prod

# Rollback if needed
kubectl argo rollouts undo myapp-prod -n prod
```

## Strategies

### Canary (Progressive Traffic Shift)
**Best for:** Most production services
**Pattern:** Gradually shift traffic: 10% → 25% → 50% → 100%

```yaml
rollout:
  enabled: true
  strategy: canary
  canary:
    steps:
      - setWeight: 10
      - pause: {duration: 10m}
      - setWeight: 50
      - pause: {duration: 15m}
```

### Blue-Green (Instant Switch)
**Best for:** Database migrations, breaking changes
**Pattern:** Deploy new version, test on preview, instant cutover

```yaml
rollout:
  enabled: true
  strategy: bluegreen
  blueGreen:
    autoPromotionEnabled: false  # Manual approval
    scaleDownDelaySeconds: 300   # 5min rollback window
```

## Environment-Specific Configurations

### Development (Fast Iteration)
```yaml
# services/myapp/values-dev.yaml
rollout:
  enabled: true
  strategy: canary
  canary:
    steps:
      - setWeight: 100  # Instant rollout in dev
```

### Staging (Moderate Testing)
```yaml
# services/myapp/values-staging.yaml
rollout:
  enabled: true
  strategy: canary
  canary:
    steps:
      - setWeight: 50
      - pause: {duration: 5m}
```

### Production (Conservative)
```yaml
# services/myapp/values-prod.yaml
rollout:
  enabled: true
  strategy: canary
  canary:
    steps:
      - setWeight: 10
      - pause: {duration: 10m}
      - setWeight: 25
      - pause: {duration: 10m}
      - setWeight: 50
      - pause: {duration: 15m}
      - setWeight: 75
      - pause: {duration: 10m}
```

## Traffic Routing Integration

### With HTTPRoute (Gateway API)
```yaml
# Argo Rollouts automatically manages traffic weights
httpRoute:
  enabled: true
  parentRefs:
    - name: platform-gateway
      namespace: istio-system

rollout:
  enabled: true
  # Rollout controller updates HTTPRoute weights automatically
```

### With Istio VirtualService
```yaml
# Enable Istio subchart
cw-istio:
  enabled: true
  virtualService:
    enabled: true

rollout:
  enabled: true
  # Rollout controller updates VirtualService weights automatically
```

## Autoscaling Integration

HPA automatically switches to reference Rollout when enabled:

```yaml
# No changes needed - HPA template handles this automatically
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

# HPA will reference:
# - kind: Deployment (when rollout.enabled=false)
# - kind: Rollout (when rollout.enabled=true)
```

## Migration Path

### Phase 1: Test with One Service
```powershell
# Pick a non-critical service
# Enable rollout in dev first
services/test-app/values-dev.yaml:
  rollout:
    enabled: true
```

### Phase 2: Expand to Staging
```powershell
# After successful dev testing
services/test-app/values-staging.yaml:
  rollout:
    enabled: true
```

### Phase 3: Production Rollout
```powershell
# Conservative prod configuration
services/test-app/values-prod.yaml:
  rollout:
    enabled: true
    canary:
      steps:
        - setWeight: 10
        - pause: {duration: 15m}
        - setWeight: 50
        - pause: {duration: 30m}
```

### Phase 4: Scale to More Services
```powershell
# Copy pattern to other services
# Each team decides independently
# No coordination needed!
```

## Scalability Considerations

### 1000+ Services with Rollouts

**Works seamlessly because:**
- ✅ No additional controllers per service
- ✅ Single Argo Rollouts controller manages all Rollouts
- ✅ Same resource overhead as Deployments
- ✅ ApplicationSet pattern unchanged

**Controller capacity:**
```
Single Argo Rollouts controller:
- Can manage 1000+ Rollout resources
- Minimal memory overhead (~50MB + 2MB per Rollout)
- For 1000 Rollouts: ~2.5 GB memory
```

**Scaling the controller:**
```yaml
# For 1000+ Rollouts, increase controller resources
resources:
  limits:
    cpu: 1000m
    memory: 4Gi
  requests:
    cpu: 500m
    memory: 2Gi
```

## Troubleshooting

### Rollout Not Progressing
```bash
# Check rollout status
kubectl describe rollout myapp-prod -n prod

# Check if paused
kubectl argo rollouts status myapp-prod -n prod

# Manually promote
kubectl argo rollouts promote myapp-prod -n prod
```

### Traffic Not Splitting
```bash
# Verify HTTPRoute or VirtualService integration
kubectl get httproute myapp-prod -n prod -o yaml
# Check for weight annotations from rollout controller

# Verify Gateway API plugin
kubectl logs -n argo-rollouts deploy/argo-rollouts
# Look for: "using Gateway API plugin"
```

### HPA Not Scaling
```bash
# Verify HPA references Rollout
kubectl get hpa myapp-prod -n prod -o yaml
# Should show: scaleTargetRef.kind: Rollout

# Check HPA status
kubectl describe hpa myapp-prod -n prod
```

## Advanced: Analysis Templates

### Prometheus Integration
```yaml
# Create AnalysisTemplate (cluster-wide)
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    successCondition: result >= 0.95
    interval: 60s
    count: 5
    provider:
      prometheus:
        address: http://prometheus.monitoring:9090
        query: |
          sum(rate(http_requests_total{job="{{args.service-name}}",status=~"2.."}[5m]))
          /
          sum(rate(http_requests_total{job="{{args.service-name}}"}[5m]))
```

### Use in Rollout
```yaml
# services/myapp/values-prod.yaml
rollout:
  enabled: true
  canary:
    steps:
      - setWeight: 10
      - pause: {duration: 5m}
      - analysis:
          templates:
          - templateName: success-rate
          args:
          - name: service-name
            value: myapp
```

## Examples

See example configurations:
- [values-prod-with-rollout.yaml](examples/values-prod-with-rollout.yaml) - Production canary
- [values-dev-with-rollout.yaml](examples/values-dev-with-rollout.yaml) - Fast dev rollout
- [values-bluegreen.yaml](examples/values-bluegreen.yaml) - Blue-green strategy

## References

- [Argo Rollouts Documentation](https://argo-rollouts.readthedocs.io/)
- [Canary Strategy](https://argo-rollouts.readthedocs.io/en/stable/features/canary/)
- [Blue-Green Strategy](https://argo-rollouts.readthedocs.io/en/stable/features/bluegreen/)
- [Traffic Management](https://argo-rollouts.readthedocs.io/en/stable/features/traffic-management/)
