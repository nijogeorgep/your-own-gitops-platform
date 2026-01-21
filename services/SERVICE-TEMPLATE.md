# Service Configuration Template

Use this template when adding a new service to the GitOps platform.

## Quick Start

1. **Create service directory:**
   ```bash
   mkdir -p services/YOUR_SERVICE_NAME
   cd services/YOUR_SERVICE_NAME
   ```

2. **Copy these files and customize:**

## base-values.yaml

```yaml
# Shared baseline configuration for all environments

replicaCount: 2

image:
  repository: YOUR_ORG/YOUR_SERVICE_NAME
  pullPolicy: IfNotPresent
  tag: "latest"

serviceAccount:
  create: true
  automount: true
  annotations: {}

podAnnotations:
  sidecar.istio.io/inject: "true"  # Enable Istio sidecar

podLabels: {}

podSecurityContext: {}

securityContext: {}

service:
  type: ClusterIP
  port: 8080  # Your service port

# Optional: Multi-port configuration
# service:
#   type: ClusterIP
#   ports:
#     - name: http
#       port: 8080
#       targetPort: 8080
#       protocol: TCP
#     - name: grpc
#       port: 9090
#       targetPort: 9090
#       protocol: TCP

httpRoute:
  enabled: false
  parentRefs: []
  rules: []

ingress:
  enabled: false

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

# Health checks (customize for your application)
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

# Environment variables (optional)
env: []
#   - name: DATABASE_URL
#     value: "postgresql://db:5432"
#   - name: API_KEY
#     valueFrom:
#       secretKeyRef:
#         name: api-secrets
#         key: api-key

# ConfigMap/Secret references (optional)
envFrom: []
#   - configMapRef:
#       name: app-config
#   - secretRef:
#       name: app-secrets

volumes: []
volumeMounts: []

nodeSelector: {}
tolerations: []
affinity: {}
```

## values-dev.yaml

```yaml
# Development environment overrides

environment: dev
region: us-east-1
# flavor: ""  # Optional - omit for standard deployment

replicaCount: 1

image:
  tag: "latest"  # Use latest in dev

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false

# Enable HTTPRoute for Istio Gateway (optional)
httpRoute:
  enabled: true
  parentRefs:
    - name: platform-gateway
      namespace: istio-system
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /YOUR_SERVICE_NAME-dev
```

## values-staging.yaml

```yaml
# Staging environment overrides

environment: staging
region: us-east-1

replicaCount: 2

image:
  tag: "stable"  # Use stable tag for staging

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 75

# Enable HTTPRoute for Istio Gateway
httpRoute:
  enabled: true
  parentRefs:
    - name: platform-gateway
      namespace: istio-system
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /YOUR_SERVICE_NAME-staging
```

## values-prod.yaml

```yaml
# Production environment overrides

environment: prod
region: us-east-1

replicaCount: 3

image:
  tag: "v1.0.0"  # Pin to specific version in production

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

# Production-grade security
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true

# Enable HTTPRoute for Istio Gateway
httpRoute:
  enabled: true
  parentRefs:
    - name: platform-gateway
      namespace: istio-system
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /YOUR_SERVICE_NAME
```

## Deployment

1. **Commit to Git:**
   ```bash
   git add services/YOUR_SERVICE_NAME/
   git commit -m "Add YOUR_SERVICE_NAME deployment configuration"
   git push origin main
   ```

2. **Wait for ApplicationSet (3 minutes):**
   ArgoCD will automatically create Applications:
   - `YOUR_SERVICE_NAME-dev`
   - `YOUR_SERVICE_NAME-staging`
   - `YOUR_SERVICE_NAME-prod`

3. **Verify:**
   ```bash
   kubectl get applications -n argocd | grep YOUR_SERVICE_NAME
   kubectl get pods -n dev -l app.kubernetes.io/name=YOUR_SERVICE_NAME
   ```

## Customization Checklist

- [ ] Update `image.repository` with your container registry
- [ ] Set correct `service.port` for your application
- [ ] Configure health check paths (`livenessProbe`, `readinessProbe`)
- [ ] Set appropriate resource limits for each environment
- [ ] Define environment variables if needed
- [ ] Configure HTTPRoute paths for Istio Gateway access
- [ ] Pin production image tag to specific version
- [ ] Review security contexts for production
- [ ] Test values locally: `helm template cw-service -f base-values.yaml -f values-dev.yaml`

## Advanced Features

### gRPC Service
```yaml
service:
  ports:
    - name: grpc
      port: 9090
      targetPort: 9090
      protocol: TCP

livenessProbe:
  grpc:
    port: 9090
readinessProbe:
  grpc:
    port: 9090
```

### Database Sidecar
```yaml
volumes:
  - name: data
    emptyDir: {}

volumeMounts:
  - name: data
    mountPath: /var/lib/db
```

### Config Files from ConfigMap
```yaml
volumes:
  - name: config
    configMap:
      name: app-config
volumeMounts:
  - name: config
    mountPath: /etc/config
    readOnly: true
```
