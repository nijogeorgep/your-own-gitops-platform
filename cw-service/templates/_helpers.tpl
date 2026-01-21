{{/*
=============================================================================
CW-SERVICE HELPERS
=============================================================================
These helpers implement the platform naming standard defined in cw-common.
Each chart must have its own copy due to Helm's chart context scoping.

Platform Naming Standard: <app-name>-<environment>-<flavor>-<region>
*/}}

{{- define "cw-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "cw-service.fullname" -}}
{{- if .Values.fullnameOverride }}
  {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
  {{- $name := default .Chart.Name .Values.nameOverride }}
  {{- $parts := list $name }}
  {{- if .Values.environment }}
    {{- $parts = append $parts .Values.environment }}
  {{- end }}
  {{- if .Values.flavor }}
    {{- $parts = append $parts .Values.flavor }}
  {{- end }}
  {{- if .Values.region }}
    {{- $parts = append $parts .Values.region }}
  {{- end }}
  {{- join "-" $parts | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "cw-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "cw-service.labels" -}}
helm.sh/chart: {{ include "cw-service.chart" . }}
{{ include "cw-service.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "cw-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cw-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "cw-service.serviceAccountName" -}}
{{- default (include "cw-service.fullname" .) .Values.serviceAccount.name }}
{{- end }}

{{/*
=============================================================================
SUBCHART VALUE INJECTION: cw-istio
=============================================================================
Purpose: Automatically populate cw-istio subchart values from parent context
Values passed:
  - service.name: Full service name from parent naming convention
  - service.port: Primary service port

This template executes before subchart rendering, ensuring Istio resources
reference the correct service created by the parent cw-service chart.

Usage: Automatically invoked by Helm during template rendering
Note: This template produces no YAML output - it only modifies .Values
*/}}
{{- if (index .Values "cw-istio" "enabled") -}}
{{- $_ := set (index .Values "cw-istio" "service") "name" (include "cw-service.fullname" .) -}}
{{- $_ := set (index .Values "cw-istio" "service") "port" .Values.service.port -}}
{{- end -}}
