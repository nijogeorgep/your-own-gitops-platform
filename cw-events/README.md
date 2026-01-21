# Argo Events + Workflows + ArgoCD Integration

## Overview

This integration creates a complete GitOps CI/CD pipeline:

```
GitHub Push → Argo Events → Argo Workflows → Update Git → ArgoCD Sync → Deploy
```

### Flow Diagram

```
┌─────────────┐
│   GitHub    │
│  (Push to   │
│    main)    │
└──────┬──────┘
       │ Webhook
       ▼
┌─────────────────────┐
│   Argo Events       │
│  (EventSource +     │
│     Sensor)         │
└──────┬──────────────┘
       │ Trigger
       ▼
┌─────────────────────────────────┐
│      Argo Workflows             │
│  1. Build container image       │
│  2. Push to registry            │
│  3. Update values-dev.yaml      │
│  4. Git commit & push           │
└──────┬──────────────────────────┘
       │ Git push
       ▼
┌─────────────────────┐
│   ApplicationSet    │
│  (Git directory     │
│   generator)        │
└──────┬──────────────┘
       │ Refresh (3min)
       ▼
┌─────────────────────┐
│   ArgoCD Apps       │
│  (nginx-dev,        │
│   nginx-staging,    │
│   nginx-prod)       │
└──────┬──────────────┘
       │ Auto-sync
       ▼
┌─────────────────────┐
│    Kubernetes       │
│   (Deployment)      │
└─────────────────────┘
```

## Components

### 1. Argo Events
**EventSources** listen for events:
- **GitHub**: Webhooks for push, PR, release
- **Calendar**: Cron-based schedules (nightly builds, cleanup)
- **Resource**: Watch Kubernetes resources (ConfigMap changes)
- **Webhook**: Generic HTTP webhooks

**Sensors** define reactions:
- Map event data to workflow parameters
- Trigger Argo Workflows
- Apply Kubernetes manifests
- Send notifications

### 2. Argo Workflows
**WorkflowTemplates** are reusable pipelines:
- `build-push-image`: Build with Kaniko, push to registry
- `update-git-values`: Update values files, commit to Git
- `run-tests`: Execute test suites
- `notify`: Send Slack/email notifications

**Workflows** are instances triggered by Events:
- Receive parameters from event payload
- Execute DAG (directed acyclic graph) of steps
- Output results for downstream processing

### 3. ArgoCD ApplicationSet
- Git directory generator detects changes every 3 minutes
- Automatically syncs dev/staging (manual for prod)
- Deploys updated manifests to Kubernetes

## Directory Structure

```
gitops-platform/
├── cw-events/              # Argo Events configurations
│   ├── eventsource-github.yaml      # GitHub webhook listener
│   ├── eventsource-calendar.yaml    # Cron-based triggers
│   ├── sensor-image-update.yaml     # Pipeline orchestration
│   └── README.md
├── cw-workflows/           # Argo Workflows templates
│   ├── workflowtemplate-build-image.yaml    # Build container
│   ├── workflowtemplate-update-git.yaml     # Update Git values
│   ├── rbac.yaml                             # Permissions
│   └── README.md
├── services/nginx/         # Service configurations
│   ├── Dockerfile          # NEW: Container build definition
│   ├── base-values.yaml
│   ├── values-dev.yaml     # Updated by Workflows
│   ├── values-staging.yaml
│   └── values-prod.yaml
└── argocd-bootstrap/       # ApplicationSet deployment
```

## Setup Instructions

### Prerequisites

1. **Argo Events installed**:
   ```powershell
   cd cw-tools
   .\install-argo-events.ps1
   ```

2. **Argo Workflows installed** (if not already):
   ```powershell
   # Install Argo Workflows
   kubectl create namespace argo-workflows
   kubectl apply -n argo-workflows -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.4/install.yaml
   ```

3. **ArgoCD with ApplicationSet** (already deployed):
   ```powershell
   cd argocd-bootstrap
   .\deploy.ps1 -GitRepoUrl "https://github.com/YOUR_ORG/gitops-platform.git"
   ```

### Step 1: Create Required Secrets

#### GitHub Access Token
```powershell
# Create GitHub personal access token with repo permissions
# https://github.com/settings/tokens

kubectl create secret generic github-access -n argo-events `
  --from-literal=token=ghp_YOUR_GITHUB_TOKEN
```

#### GitHub Webhook Secret
```powershell
# Generate random secret for webhook validation
$webhookSecret = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})

kubectl create secret generic github-webhook-secret -n argo-events `
  --from-literal=secret=$webhookSecret

Write-Host "Webhook Secret: $webhookSecret" -ForegroundColor Yellow
Write-Host "Save this for GitHub webhook configuration" -ForegroundColor Yellow
```

#### Git Credentials for Workflows
```powershell
# Token with write permissions to update Git repository
kubectl create secret generic git-credentials -n argo-workflows `
  --from-literal=token=ghp_YOUR_GITHUB_TOKEN
```

#### Container Registry Credentials
```powershell
# Docker Hub example
kubectl create secret docker-registry regcred -n argo-workflows `
  --docker-server=docker.io `
  --docker-username=YOUR_USERNAME `
  --docker-password=YOUR_PASSWORD

# Or for GitHub Container Registry (ghcr.io)
kubectl create secret docker-registry regcred -n argo-workflows `
  --docker-server=ghcr.io `
  --docker-username=YOUR_GITHUB_USERNAME `
  --docker-password=ghp_YOUR_GITHUB_TOKEN
```

### Step 2: Deploy RBAC

```powershell
kubectl apply -f cw-workflows/rbac.yaml
```

Verify:
```powershell
kubectl get sa workflow-executor -n argo-workflows
kubectl get sa argo-events-sa -n argo-events
```

### Step 3: Update Configuration

Edit these files with your details:

1. **cw-events/eventsource-github.yaml**:
   - `owner`: Your GitHub org/username
   - `repository`: Your repository name

2. **cw-workflows/workflowtemplate-build-image.yaml**:
   - `git-repo`: Your Git repository URL
   - `image-repository`: Your container registry (e.g., `ghcr.io/yourorg` or `docker.io/youruser`)

3. **cw-workflows/workflowtemplate-update-git.yaml**:
   - `git-repo`: Your Git repository URL

### Step 4: Deploy EventSources

```powershell
kubectl apply -f cw-events/eventsource-github.yaml
kubectl apply -f cw-events/eventsource-calendar.yaml
```

Verify EventSources:
```powershell
kubectl get eventsource -n argo-events
kubectl get pods -n argo-events -l eventsource-name=github
```

### Step 5: Deploy WorkflowTemplates

```powershell
kubectl apply -f cw-workflows/workflowtemplate-build-image.yaml
kubectl apply -f cw-workflows/workflowtemplate-update-git.yaml
```

Verify:
```powershell
kubectl get workflowtemplate -n argo-workflows
```

### Step 6: Deploy Sensors

```powershell
kubectl apply -f cw-events/sensor-image-update.yaml
```

Verify:
```powershell
kubectl get sensor -n argo-events
kubectl get pods -n argo-events -l sensor-name=image-update-pipeline
```

### Step 7: Configure GitHub Webhook

1. Go to your GitHub repository → **Settings** → **Webhooks** → **Add webhook**

2. **Payload URL**: 
   - **Local testing**: `kubectl port-forward -n argo-events svc/github-eventsource-svc 12000:12000`
     Then use ngrok: `ngrok http 12000` → Use ngrok URL
   - **Production**: Expose via Istio Gateway (see below)

3. **Content type**: `application/json`

4. **Secret**: Use the webhook secret from Step 1

5. **Events**: Select:
   - ✅ Pushes
   - ✅ Pull requests
   - ✅ Releases

6. **Active**: ✅ Checked

### Step 8: Create Dockerfile for Service

```powershell
# Example Dockerfile for nginx service
cd services/nginx

@"
FROM nginx:alpine

# Copy custom configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy static files (if any)
# COPY ./html /usr/share/nginx/html

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
"@ | Out-File -FilePath Dockerfile -Encoding utf8
```

## Testing the Pipeline

### Manual Workflow Trigger

Test the build pipeline without GitHub:

```powershell
# Submit workflow directly
kubectl create -n argo-workflows -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: test-build-
spec:
  serviceAccountName: workflow-executor
  workflowTemplateRef:
    name: build-push-image
  arguments:
    parameters:
      - name: service-name
        value: "nginx"
      - name: git-revision
        value: "main"
      - name: image-tag
        value: "test-$(date +%s)"
EOF
```

Watch workflow:
```powershell
# Get workflow name
kubectl get workflows -n argo-workflows

# Watch logs
kubectl logs -n argo-workflows -l workflows.argoproj.io/workflow=<workflow-name> -f

# Or use Argo Workflows UI
kubectl port-forward -n argo-workflows svc/argo-server 2746:2746
# Open: https://localhost:2746
```

### Test Event Flow

1. **Push code to GitHub**:
   ```powershell
   # Make a change to nginx service
   cd services/nginx
   echo "# Updated" >> README.md
   git add README.md
   git commit -m "test: trigger pipeline"
   git push origin main
   ```

2. **Check EventSource received webhook**:
   ```powershell
   kubectl logs -n argo-events -l eventsource-name=github --tail=50
   ```

3. **Check Sensor triggered Workflow**:
   ```powershell
   kubectl logs -n argo-events -l sensor-name=image-update-pipeline --tail=50
   ```

4. **Watch Workflow execution**:
   ```powershell
   kubectl get workflows -n argo-workflows --watch
   ```

5. **Verify Git update**:
   ```powershell
   # Check if values-dev.yaml was updated
   git pull origin main
   cat services/nginx/values-dev.yaml | grep "tag:"
   ```

6. **Check ArgoCD sync**:
   ```powershell
   # Wait up to 3 minutes for ApplicationSet refresh
   kubectl get applications -n argocd -l service=nginx --watch
   ```

## Integration Patterns

### Pattern 1: Automated Dev Deployment
```
Git Push → Build Image → Update values-dev.yaml → ArgoCD Auto-Sync → Dev Deployed
```
**Use case**: Continuous deployment to dev environment

### Pattern 2: Staged Promotion
```
Tag Release → Build Image → Update all values → Manual ArgoCD Sync for Prod
```
**Use case**: Release v1.2.3 to all environments with production gate

### Pattern 3: PR Preview Environments
```
PR Opened → Create Namespace → Deploy Preview → Comment PR with URL
```
**Use case**: Ephemeral environments for testing PRs

### Pattern 4: Scheduled Operations
```
Cron Event → Cleanup Workflow → Remove old images/resources
```
**Use case**: Nightly cleanup, weekly reports

## Expose GitHub Webhook via Istio Gateway

For production, expose EventSource through Istio:

```yaml
# Add to cw-gateway/
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: github-webhook
  namespace: argo-events
spec:
  parentRefs:
    - name: platform-gateway
      namespace: istio-system
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /webhooks/github
      backendRefs:
        - name: github-eventsource-svc
          port: 12000
```

Then configure GitHub webhook URL: `https://your-domain.com/webhooks/github`

## Monitoring & Troubleshooting

### View EventSource Status
```powershell
kubectl describe eventsource github -n argo-events
kubectl logs -n argo-events -l eventsource-name=github
```

### View Sensor Status
```powershell
kubectl describe sensor image-update-pipeline -n argo-events
kubectl logs -n argo-events -l sensor-name=image-update-pipeline
```

### View Workflows
```powershell
# List workflows
kubectl get workflows -n argo-workflows

# Get workflow details
kubectl describe workflow <workflow-name> -n argo-workflows

# View logs
kubectl logs -n argo-workflows -l workflows.argoproj.io/workflow=<workflow-name>
```

### Common Issues

**EventSource not receiving webhooks**:
- Check service is running: `kubectl get svc github-eventsource-svc -n argo-events`
- Verify port-forward or Istio route
- Check GitHub webhook delivery logs
- Validate webhook secret matches

**Sensor not triggering Workflow**:
- Check sensor logs for filter matches
- Verify RBAC permissions
- Check event payload matches filters

**Workflow fails to build image**:
- Verify Dockerfile exists in `services/<name>/`
- Check registry credentials: `kubectl get secret regcred -n argo-workflows`
- Review Kaniko logs in workflow pods

**Workflow fails to update Git**:
- Verify Git credentials: `kubectl get secret git-credentials -n argo-workflows`
- Check token has write permissions
- Ensure git-username and git-email are set

**ArgoCD not syncing updated values**:
- ApplicationSet refresh interval is 3 minutes
- Force refresh: `argocd app get nginx-dev --refresh`
- Check Application sync policy allows auto-sync

## Advanced Configurations

### Multi-Environment Promotion

```yaml
# Sensor that promotes dev → staging after tests pass
- template:
    name: promote-to-staging
    conditions: "{{tasks.run-tests.outputs.result}} == success"
    k8s:
      operation: create
      source:
        resource:
          apiVersion: argoproj.io/v1alpha1
          kind: Workflow
          spec:
            workflowTemplateRef:
              name: update-git-values
            arguments:
              parameters:
                - name: environment
                  value: "staging"
                - name: new-image-tag
                  value: "{{tasks.build-image.outputs.parameters.image-tag}}"
```

### Notification Integration

```yaml
# Add Slack notification step to Workflow
- name: notify-slack
  container:
    image: curlimages/curl:latest
    command: [sh, -c]
    args:
      - |
        curl -X POST $SLACK_WEBHOOK_URL \
          -H 'Content-Type: application/json' \
          -d '{
            "text": "Deployed {{workflow.parameters.service-name}} to dev",
            "blocks": [{
              "type": "section",
              "text": {
                "type": "mrkdwn",
                "text": "*Service*: {{workflow.parameters.service-name}}\n*Tag*: {{workflow.parameters.image-tag}}\n*Status*: ✅ Success"
              }
            }]
          }'
```

### Rollback on Failure

```yaml
# Workflow with automatic rollback
templates:
  - name: deploy-with-rollback
    dag:
      tasks:
        - name: deploy
          template: update-git-values
        
        - name: health-check
          template: check-deployment-health
          depends: "deploy"
        
        - name: rollback
          template: revert-git-commit
          depends: "health-check"
          when: "{{tasks.health-check.status}} == Failed"
```

## References

- [Argo Events Documentation](https://argoproj.github.io/argo-events/)
- [Argo Workflows Documentation](https://argoproj.github.io/argo-workflows/)
- [ArgoCD ApplicationSet](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- [Kaniko Documentation](https://github.com/GoogleContainerTools/kaniko)
