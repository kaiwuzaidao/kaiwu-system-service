{{- define "kaiwu.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "kaiwu.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "kaiwu.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "kaiwu.labels" -}}
app.kubernetes.io/name: {{ include "kaiwu.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
{{- end -}}

{{- define "kaiwu.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kaiwu.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "kaiwu.secretName" -}}
{{- required "runtimeSecret.existingSecret is required" .Values.runtimeSecret.existingSecret -}}
{{- end -}}

{{- define "kaiwu.databaseHost" -}}
{{- if .Values.database.embedded -}}
{{- printf "%s-mysql" (include "kaiwu.fullname" .) -}}
{{- else -}}
{{- required "database.host is required when database.embedded=false" .Values.database.host -}}
{{- end -}}
{{- end -}}

{{- define "kaiwu.redisHost" -}}
{{- if .Values.redis.embedded -}}
{{- printf "%s-redis" (include "kaiwu.fullname" .) -}}
{{- else -}}
{{- required "redis.host is required when redis.embedded=false" .Values.redis.host -}}
{{- end -}}
{{- end -}}

{{/*
System 的对外地址（ADR 0024）。留空则用集群内 Service DNS，
显式配置则原样透传——由它的 scheme 决定 Gateway 用哪种方式解析。
*/}}
{{- define "kaiwu.systemServiceUri" -}}
{{- if .Values.serviceAddressing.systemServiceUri -}}
{{- .Values.serviceAddressing.systemServiceUri -}}
{{- else -}}
{{- printf "http://%s-system:8080" (include "kaiwu.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "kaiwu.image" -}}
{{- if .digest -}}
{{- printf "%s@%s" .repository .digest -}}
{{- else -}}
{{- printf "%s:%s" .repository .tag -}}
{{- end -}}
{{- end -}}
