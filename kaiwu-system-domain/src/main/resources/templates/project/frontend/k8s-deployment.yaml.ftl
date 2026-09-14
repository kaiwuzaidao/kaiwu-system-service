apiVersion: apps/v1
kind: Deployment
metadata:
  name: kaiwu-${projectCode}-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kaiwu-${projectCode}-web
  template:
    metadata:
      labels:
        app: kaiwu-${projectCode}-web
    spec:
      automountServiceAccountToken: false
      containers:
        - name: web
          image: kaiwu-${projectCode}-web:replace-me
          ports:
            - name: http
              containerPort: 8080
          readinessProbe:
            httpGet: { path: /apps/${projectCode}/, port: http }
          livenessProbe:
            httpGet: { path: /apps/${projectCode}/, port: http }
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: { drop: ["ALL"] }
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        runAsGroup: 101
        seccompProfile: { type: RuntimeDefault }
