# cw-rollout

**Advanced Progressive Delivery Subchart for Kubernetes**

This subchart provides Argo Rollouts integration with analysis templates for automated canary and blue-green deployments.

## Features

- **Progressive Delivery Strategies**
  - Canary deployments with gradual traffic shifting
  - Blue-green deployments with instant switch
  - Automated rollback on analysis failure

- **Multi-Provider Analysis Templates**
  - **Prometheus** - Success rate, error rate, latency (P95) monitoring
  - **Datadog** - API-based metrics analysis
  - **New Relic** - NRQL queries for APM data
  - **Webhook** - Custom health check integrations

- **Experimentation**
  - A/B testing support
  - Traffic splitting for experiments
  - Metric-driven validation

- **Notifications** (Optional)
  - Slack/Teams integration for rollout events
  - Webhook notifications for promotion/rollback

## Architecture

This subchart is **conditionally enabled** as a dependency of the `cw-service` chart:

```yaml
# cw-service/Chart.yaml
dependencies:
  - name: cw-rollout
    version: 0.1.0
    condition: cw-rollout.enabled
```

When enabled (`cw-rollout.enabled: true`), the parent chart's Deployment is automatically disabled to prevent resource conflicts.

## Usage

### Basic Canary Rollout

```yaml
# services/myapp/values-prod.yaml
cw-rollout:
  enabled: true
  rollout:
    strategy: canary
    canary:
      steps:
        - setWeight: 10
        - pause: {duration: 5m}
        - setWeight: 25
        - pause: {duration: 10m}
        - setWeight: 50
        - pause: {duration: 15m}
```

### Canary with Prometheus Analysis

```yaml
# services/myapp/values-prod.yaml
cw-rollout:
  enabled: true
  rollout:
    strategy: canary
    canary:
      steps:
        - setWeight: 10
        - pause: {duration: 2m}
        - analysis:
            templates:
              - templateName: prometheus-success-rate
        - setWeight: 50
        - pause: {duration: 5m}
        - analysis:
            templates:
              - templateName: prometheus-error-rate
              - templateName: prometheus-latency-p95

  # Enable Prometheus analysis templates
  analysisTemplates:
    prometheus:
      enabled: true
      address: http://prometheus.monitoring:9090
      queries:
        successRate:
          enabled: true
          query: |
            sum(rate(
              http_requests_total{job="myapp-prod-us-east-1",code=~"2.."}[5m]
            )) /
            sum(rate(
              http_requests_total{job="myapp-prod-us-east-1"}[5m]
            ))
          threshold: 0.95  # 95% success rate required
        errorRate:
          enabled: true
          query: |
            sum(rate(
              http_requests_total{job="myapp-prod-us-east-1",code=~"5.."}[5m]
            )) /
            sum(rate(
              http_requests_total{job="myapp-prod-us-east-1"}[5m]
            ))
          threshold: 0.05  # Max 5% errors
        latency:
          enabled: true
          query: |
            histogram_quantile(0.95,
              sum(rate(http_request_duration_seconds_bucket{job="myapp-prod-us-east-1"}[5m])) by (le)
            ) * 1000
          threshold: 500  # P95 latency < 500ms
```

### Blue-Green with Datadog Analysis

```yaml
# services/myapp/values-prod.yaml
cw-rollout:
  enabled: true
  rollout:
    strategy: bluegreen
    blueGreen:
      autoPromotionEnabled: false  # Require manual approval
      scaleDownDelaySeconds: 300   # Keep old version for 5min
      prePromotionAnalysis:
        templates:
          - templateName: datadog-health-check

  analysisTemplates:
    datadog:
      enabled: true
      apiKey: "your-datadog-api-key"  # Use secret in production
      appKey: "your-datadog-app-key"
      address: https://api.datadoghq.com
      queries:
        errorRate:
          enabled: true
          query: "avg:trace.http.request.errors{service:myapp,env:prod}.as_rate()"
          threshold: 0.05
        latency:
          enabled: true
          query: "avg:trace.http.request.duration{service:myapp,env:prod}.rollup(avg, 60)"
          threshold: 500
```

### New Relic Integration

```yaml
# services/myapp/values-prod.yaml
cw-rollout:
  enabled: true
  analysisTemplates:
    newrelic:
      enabled: true
      apiKey: "your-newrelic-api-key"
      accountId: "1234567"
      region: us  # or eu
      queries:
        errorPercentage:
          enabled: true
          nrql: "FROM Transaction SELECT percentage(count(*), WHERE error IS true) WHERE appName = 'myapp-prod'"
          threshold: 5  # Max 5%
        apdex:
          enabled: true
          nrql: "FROM Transaction SELECT apdex(duration, t: 0.5) WHERE appName = 'myapp-prod'"
          threshold: 0.95  # Min 0.95 Apdex
```

### Custom Webhook Analysis

```yaml
# services/myapp/values-prod.yaml
cw-rollout:
  enabled: true
  analysisTemplates:
    webhook:
      enabled: true
      webhooks:
        customHealthCheck:
          enabled: true
          url: https://myapp-health-checker.example.com/check
          method: POST
          headers:
            - key: Authorization
              value: "Bearer {{ .Values.healthCheckToken }}"
          body: |
            {
              "service": "{{ include "cw-rollout.fullname" . }}",
              "namespace": "{{ .Release.Namespace }}",
              "version": "{{ .Values.image.tag }}"
            }
          jsonPath: "{$.health.status}"
          successCondition: "result == 'healthy'"
```

### A/B Testing Experiment

```yaml
# services/myapp/values-prod.yaml
cw-rollout:
  enabled: true
  experiments:
    enabled: true
    templates:
      - name: feature-ab-test
        duration: 1h
        spec:
          templates:
            - name: baseline
              replicas: 2
            - name: canary
              replicas: 1
          analyses:
            - name: success-rate
              templateName: prometheus-success-rate
```

## Traffic Routing Integration

### Gateway API (HTTPRoute)

```yaml
# Automatic integration with parent chart's HTTPRoute
httpRoute:
  enabled: true
  parentRefs:
    - name: gateway
      sectionName: http

cw-rollout:
  enabled: true
  # Traffic routing automatically uses HTTPRoute
```

### Istio VirtualService

```yaml
# Automatic integration with cw-istio subchart
cw-istio:
  enabled: true
  virtualService:
    enabled: true

cw-rollout:
  enabled: true
  # Traffic routing automatically uses VirtualService
```

## Analysis Templates

### Prometheus

**Metrics provided:**
- `success-rate` - HTTP success rate (2xx/total)
- `error-rate` - HTTP error rate (5xx/total)
- `latency-p95` - P95 response time

**Configuration:**
```yaml
analysisTemplates:
  prometheus:
    enabled: true
    address: http://prometheus.monitoring:9090
    queries:
      successRate:
        enabled: true
        query: "YOUR_PROMQL_QUERY"
        threshold: 0.95
```

### Datadog

**Metrics provided:**
- `error-rate` - Trace error rate
- `latency` - Average request duration

**Configuration:**
```yaml
analysisTemplates:
  datadog:
    enabled: true
    apiKey: "secret-api-key"
    appKey: "secret-app-key"
    queries:
      errorRate:
        query: "avg:trace.http.request.errors{service:myapp}.as_rate()"
        threshold: 0.05
```

### New Relic

**Metrics provided:**
- `error-percentage` - Transaction error percentage
- `apdex` - Application Performance Index

**Configuration:**
```yaml
analysisTemplates:
  newrelic:
    enabled: true
    apiKey: "YOUR_API_KEY"
    accountId: "YOUR_ACCOUNT_ID"
    region: us  # or eu
```

### Webhook

**Use cases:**
- Custom health check services
- Third-party monitoring integrations
- Business metric validation

**Configuration:**
```yaml
analysisTemplates:
  webhook:
    enabled: true
    webhooks:
      myHealthCheck:
        url: https://example.com/check
        method: POST
        jsonPath: "{$.status}"
        successCondition: "result == 'ok'"
```

## Scalability

This subchart pattern scales to **1000+ services**:

✅ **Service-level opt-in**: Each service independently enables rollouts in environment-specific values files  
✅ **No coordination needed**: Services can enable/disable rollouts without affecting others  
✅ **Analysis template reuse**: Shared templates across all services (defined once, used everywhere)  
✅ **Conditional rendering**: Rollout resources only created when enabled

**Example at scale:**
```
services/
├── api-gateway/
│   └── values-prod.yaml (cw-rollout.enabled: true)
├── user-service/
│   └── values-prod.yaml (cw-rollout.enabled: true)
├── payment-service/
│   └── values-prod.yaml (cw-rollout.enabled: false)  # Standard deployment
└── ... (997 more services)
```

## Best Practices

### 1. Environment-Specific Enablement
```yaml
# values-dev.yaml - Fast iteration
cw-rollout:
  enabled: false  # Use standard Deployment

# values-prod.yaml - Safe progressive delivery
cw-rollout:
  enabled: true
  rollout:
    strategy: canary
```

### 2. Gradual Rollout Steps
```yaml
# Conservative production rollout
canary:
  steps:
    - setWeight: 5
    - pause: {duration: 5m}
    - analysis: {...}
    - setWeight: 10
    - pause: {duration: 10m}
    - analysis: {...}
    - setWeight: 25
    - pause: {duration: 15m}
    - analysis: {...}
    - setWeight: 50
    - pause: {duration: 20m}
```

### 3. Multiple Analysis Providers
```yaml
# Combine multiple signals for confidence
canary:
  steps:
    - setWeight: 25
    - analysis:
        templates:
          - templateName: prometheus-success-rate
          - templateName: prometheus-latency-p95
          - templateName: datadog-error-rate
          - templateName: webhook-business-metrics
```

### 4. Secrets Management
```yaml
# Use Kubernetes Secrets for API keys
analysisTemplates:
  datadog:
    apiKey:
      secretName: datadog-credentials
      secretKey: api-key
    appKey:
      secretName: datadog-credentials
      secretKey: app-key
```

## Anti-Patterns to Avoid

❌ **Don't enable both Deployment and Rollout** - Mutually exclusive resources  
❌ **Don't skip analysis in production** - Always validate canary health  
❌ **Don't use aggressive traffic shifts** - Gradual is safer (5% → 10% → 25% → 50%)  
❌ **Don't hardcode secrets** - Use Kubernetes Secrets or External Secrets Operator  
❌ **Don't auto-promote in production without analysis** - Require validation gates

## Troubleshooting

### Rollout stuck in Progressing state
```bash
# Check rollout status
kubectl argo rollouts get rollout myapp-prod -n namespace

# Check analysis run
kubectl get analysisrun -n namespace
kubectl describe analysisrun <name> -n namespace

# View rollout events
kubectl describe rollout myapp-prod -n namespace
```

### Analysis failing
```bash
# Check AnalysisRun logs
kubectl logs -l analysisrun=<name> -n namespace

# Verify metrics provider connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://prometheus.monitoring:9090/-/healthy
```

### Manual rollout control
```bash
# Promote canary to stable
kubectl argo rollouts promote myapp-prod -n namespace

# Abort rollout
kubectl argo rollouts abort myapp-prod -n namespace

# Retry rollout
kubectl argo rollouts retry myapp-prod -n namespace
```

## Migration Guide

### From Conditional Template to Subchart

**Old pattern (deprecated):**
```yaml
# values-prod.yaml
rollout:
  enabled: true
```

**New pattern (recommended):**
```yaml
# values-prod.yaml
cw-rollout:
  enabled: true
  rollout:
    strategy: canary
```

**Migration steps:**
1. Update `values-<env>.yaml` to use `cw-rollout.enabled` instead of `rollout.enabled`
2. Nest rollout configuration under `cw-rollout.rollout`
3. Run `helm dependency update cw-service` to fetch subchart
4. Upgrade release: `helm upgrade myapp-prod ./cw-service -f values-prod.yaml`

## Dependencies

- **cw-common** (0.1.0) - Library chart for shared helpers
- **Argo Rollouts** (≥1.6.0) - Progressive delivery controller
- **Metrics Provider** - Prometheus, Datadog, New Relic, or custom webhook

## Contributing

When adding new analysis providers:
1. Create template in `templates/analysistemplate-<provider>.yaml`
2. Add configuration schema to `values.yaml` under `analysisTemplates.<provider>`
3. Document usage examples in this README
4. Test with real metrics provider before production use

## See Also

- [Argo Rollouts Documentation](https://argo-rollouts.readthedocs.io/)
- [Analysis Templates Guide](https://argo-rollouts.readthedocs.io/en/stable/features/analysis/)
- [Gateway API Routing](https://gateway-api.sigs.k8s.io/)
- [cw-service Chart](../../README.md)
