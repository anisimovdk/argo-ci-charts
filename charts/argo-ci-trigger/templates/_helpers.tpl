{{/*
Expand the name of the chart.
*/}}
{{- define "argo-ci-trigger.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "argo-ci-trigger.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "argo-ci-trigger.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "argo-ci-trigger.labels" -}}
helm.sh/chart: {{ include "argo-ci-trigger.chart" . }}
{{ include "argo-ci-trigger.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "argo-ci-trigger.selectorLabels" -}}
app.kubernetes.io/name: {{ include "argo-ci-trigger.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Webhook secret name based on release name
Returns "<release-name>-webhook-secret"
*/}}
{{- define "argo-ci-trigger.webhookSecretName" -}}
{{- printf "%s-webhook-secret" (include "argo-ci-trigger.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
API token secret name based on release name
Returns "<release-name>-api-token"
*/}}
{{- define "argo-ci-trigger.apiTokenSecretName" -}}
{{- printf "%s-api-token" (include "argo-ci-trigger.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Get ExternalSecret name based on release name
Returns templated name for all secrets: <release-name>-<secret-name>
*/}}
{{- define "argo-ci-trigger.externalSecretName" -}}
{{- $name := .name }}
{{- $root := .root }}
{{- printf "%s-%s" (include "argo-ci-trigger.fullname" $root) $name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Get secretStore kind for ExternalSecret
Returns the secret-specific kind if set, otherwise falls back to default secretStore kind
*/}}
{{- define "argo-ci-trigger.externalSecretStoreKind" -}}
{{- $secret := .secret }}
{{- $root := .root }}
{{- if and $secret.secretStoreRef $secret.secretStoreRef.kind }}
{{- $secret.secretStoreRef.kind }}
{{- else }}
{{- required "externalSecrets.secretStore.kind is required when creating ExternalSecrets" $root.Values.externalSecrets.secretStore.kind }}
{{- end }}
{{- end }}

{{/*
Get secretStore name for ExternalSecret
Returns the secret-specific name if set, otherwise falls back to default secretStore name
*/}}
{{- define "argo-ci-trigger.externalSecretStoreName" -}}
{{- $secret := .secret }}
{{- $root := .root }}
{{- if and $secret.secretStoreRef $secret.secretStoreRef.name }}
{{- $secret.secretStoreRef.name }}
{{- else }}
{{- required "externalSecrets.secretStore.name is required when creating ExternalSecrets" $root.Values.externalSecrets.secretStore.name }}
{{- end }}
{{- end }}

{{/*
Validate that at least one eventSource is configured with a repository
*/}}
{{- define "argo-ci-trigger.validateEventSource" -}}
{{- if not .Values.eventSource.github.repository }}
{{- fail "eventSource.github.repository must be defined. At least one eventSource with a configured repository is required." }}
{{- end }}
{{- end }}
