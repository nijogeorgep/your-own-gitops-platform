# cw-common Library Chart

## Purpose
Common library chart providing shared Helm helpers and utilities for all `cw-*` charts in the platform.

## Type
**Library Chart** (`type: library`) - Does not deploy any resources directly. Only provides reusable template helpers.

## Available Helpers

### `cw-common.name`
Extracts the application name from chart configuration.
- Returns: `.Values.nameOverride` or `.Chart.Name`

### `cw-common.fullname`
Generates resource names following platform naming standard.
- **Format**: `<app-name>-<environment>-<flavor>-<region>`
- **Components**:
  - `app-name`: From nameOverride or Chart.Name (required)
  - `environment`: dev, staging, prod, etc. (optional)
  - `flavor`: Service variant like api, worker, cache (optional)
  - `region`: Cloud region like us-east-1, eu-west-1 (optional)
- **Examples**:
  - Full: `myapp-prod-api-us-east-1`
  - No flavor: `myapp-prod-us-east-1`
  - Minimal: `myapp-dev`
- **DNS Compliance**: Automatically truncated to 63 characters

### `cw-common.chart`
Generates chart label value combining name and version.
- **Format**: `<chart-name>-<version>`
- Used in `helm.sh/chart` label

### `cw-common.labels`
Generates standard Kubernetes recommended labels:
```yaml
helm.sh/chart: <chart-name>-<version>
app.kubernetes.io/name: <app-name>
app.kubernetes.io/instance: <release-name>
app.kubernetes.io/version: <app-version>
app.kubernetes.io/managed-by: Helm
```

### `cw-common.selectorLabels`
Generates pod selector labels for Services and Deployments:
```yaml
app.kubernetes.io/name: <app-name>
app.kubernetes.io/instance: <release-name>
```

### `cw-common.serviceAccountName`
Determines the ServiceAccount name to use:
- Returns: `.Values.serviceAccount.name` or generated fullname

## Usage in Dependent Charts

### 1. Add Dependency in Chart.yaml
```yaml
dependencies:
  - name: cw-common
    version: 0.1.0
    repository: "file://../cw-common"
```

### 2. Create Aliases in templates/_helpers.tpl
```yaml
{{/* Backward compatibility alias */}}
{{- define "my-chart.fullname" -}}
{{- include "cw-common.fullname" . }}
{{- end }}
```

### 3. Use in Templates
```yaml
metadata:
  name: {{ include "cw-common.fullname" . }}
  labels:
    {{- include "cw-common.labels" . | nindent 4 }}
```

## Required Values
Charts using cw-common should provide these values:
```yaml
nameOverride: ""  # Optional: Override chart name
fullnameOverride: ""  # Optional: Bypass naming convention
environment: ""  # e.g., dev, staging, prod
flavor: ""  # Optional: e.g., api, worker
region: ""  # e.g., us-east-1, eu-west-1

serviceAccount:
  name: ""  # Optional: Custom SA name
```

## Charts Using cw-common
- `cw-service` - Main application chart
- `cw-istio` - Istio service mesh resources
- Future cw-* charts

## Maintenance
When adding new shared helpers:
1. Add to `templates/_helpers.tpl` with full documentation
2. Update this README with usage examples
3. Increment version in `Chart.yaml`
4. Update dependent charts' `Chart.yaml` to new version
5. Run `helm dependency update` in dependent charts
