{{/*
Create chart name for cw-rollout
*/}}
{{- define "cw-rollout.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name (uses parent chart's fullname)
*/}}
{{- define "cw-rollout.fullname" -}}
{{- include "cw-common.fullname" . }}
{{- end }}

{{/*
Common labels (inherits from parent)
*/}}
{{- define "cw-rollout.labels" -}}
{{- include "cw-common.labels" . }}
app.kubernetes.io/component: progressive-delivery
{{- end }}

{{/*
Selector labels (inherits from parent)
*/}}
{{- define "cw-rollout.selectorLabels" -}}
{{- include "cw-common.selectorLabels" . }}
{{- end }}
