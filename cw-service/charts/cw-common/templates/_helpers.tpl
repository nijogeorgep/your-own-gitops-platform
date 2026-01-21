{{/*
=============================================================================
CW-COMMON LIBRARY CHART - SHARED HELPERS
=============================================================================
Purpose: Provide reusable helper templates for all cw-* charts
Type: Library chart (no resources rendered directly)
Usage: Add cw-common as dependency in Chart.yaml, then use helpers

Available helpers:
  - cw-common.name: Extract chart name
  - cw-common.fullname: Platform naming standard <app>-<env>-<flavor>-<region>
  - cw-common.chart: Chart label value
  - cw-common.labels: Standard Kubernetes labels
  - cw-common.selectorLabels: Pod selector labels
  - cw-common.serviceAccountName: ServiceAccount name resolver
*/}}

{{/*
=============================================================================
HELPER TEMPLATE: cw-common.name
=============================================================================
Purpose: Extract application name from chart configuration
Logic:
  1. Use .Values.nameOverride if provided
  2. Fall back to .Chart.Name

Returns: Application name string (e.g., "myapp")
Used by: cw-common.fullname for name construction
*/}}
{{- define "cw-common.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
=============================================================================
HELPER TEMPLATE: cw-common.fullname
=============================================================================
Purpose: Generate resource names following platform naming standard
Format: <app-name>-<environment>-<flavor>-<region>

Components (all optional except app name):
  - app-name: From nameOverride or Chart.Name
  - environment: dev, staging, prod, etc.
  - flavor: Service variant (api, worker, cache) - OPTIONAL
  - region: Cloud region (us-east-1, eu-west-1, etc.)

Examples:
  myapp-prod-api-us-east-1 (all components)
  myapp-prod-us-east-1 (no flavor)
  myapp-dev (minimal)

DNS Compliance: Truncated to 63 chars, trailing hyphens removed
Override: Use .Values.fullnameOverride to bypass convention
*/}}
{{- define "cw-common.fullname" -}}
{{- if .Values.fullnameOverride }}
  {{/* Complete override - user provides exact name */}}
  {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
  {{/* Build name from components following platform standard */}}
  {{- $name := default .Chart.Name .Values.nameOverride }}
  {{- $parts := list $name }}
  
  {{/* Add environment if specified */}}
  {{- if .Values.environment }}
    {{- $parts = append $parts .Values.environment }}
  {{- end }}
  
  {{/* Add flavor if specified (optional component) */}}
  {{- if .Values.flavor }}
    {{- $parts = append $parts .Values.flavor }}
  {{- end }}
  
  {{/* Add region if specified */}}
  {{- if .Values.region }}
    {{- $parts = append $parts .Values.region }}
  {{- end }}
  
  {{/* Join components with hyphens, truncate to DNS limit */}}
  {{- join "-" $parts | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
=============================================================================
HELPER TEMPLATE: cw-common.chart
=============================================================================
Purpose: Generate chart label value combining name and version
Format: <chart-name>-<version> (+ replaced with _)
Used by: Chart metadata label in all resources
*/}}
{{- define "cw-common.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
=============================================================================
HELPER TEMPLATE: cw-common.labels
=============================================================================
Purpose: Generate standard Kubernetes labels for all resources
Includes:
  - helm.sh/chart: Chart name and version
  - app.kubernetes.io/name: Application name
  - app.kubernetes.io/instance: Release instance
  - app.kubernetes.io/version: Application version (from Chart.AppVersion)
  - app.kubernetes.io/managed-by: Helm release service

Usage: Add to metadata.labels in all resource templates
*/}}
{{- define "cw-common.labels" -}}
helm.sh/chart: {{ include "cw-common.chart" . }}
{{ include "cw-common.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
=============================================================================
HELPER TEMPLATE: cw-common.selectorLabels
=============================================================================
Purpose: Generate pod selector labels for Services and Deployments
Labels:
  - app.kubernetes.io/name: Application identifier
  - app.kubernetes.io/instance: Release instance (allows multiple installs)

Important: These labels MUST match between:
  - Deployment spec.template.metadata.labels
  - Deployment spec.selector.matchLabels
  - Service spec.selector
*/}}
{{- define "cw-common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cw-common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
=============================================================================
HELPER TEMPLATE: cw-common.serviceAccountName
=============================================================================
Purpose: Determine the service account name to use for pods
Logic: ServiceAccount is always created - uses custom name or generated fullname

Returns: Service account name string
*/}}
{{- define "cw-common.serviceAccountName" -}}
{{- default (include "cw-common.fullname" .) .Values.serviceAccount.name }}
{{- end }}
