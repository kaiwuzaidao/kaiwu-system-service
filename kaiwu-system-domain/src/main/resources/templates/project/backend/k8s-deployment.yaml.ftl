apiVersion: apps/v1
kind: Deployment
metadata:
  name: kaiwu-${projectCode}-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kaiwu-${projectCode}-service
  template:
    metadata:
      labels:
        app: kaiwu-${projectCode}-service
    spec:
      automountServiceAccountToken: false
      containers:
        - name: service
          image: kaiwu-${projectCode}-service:replace-me
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: DB_HOST
              valueFrom:
                secretKeyRef: { name: kaiwu-${projectCode}-runtime, key: db-host }
            - name: DB_PORT
              valueFrom:
                secretKeyRef: { name: kaiwu-${projectCode}-runtime, key: db-port }
            - name: DB_NAME
              valueFrom:
                secretKeyRef: { name: kaiwu-${projectCode}-runtime, key: db-name }
            - name: DB_USER
              valueFrom:
                secretKeyRef: { name: kaiwu-${projectCode}-runtime, key: db-user }
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef: { name: kaiwu-${projectCode}-runtime, key: db-password }
            - name: KAIWU_CONTEXT_PUBLIC_KEY
              valueFrom:
                secretKeyRef: { name: kaiwu-${projectCode}-runtime, key: context-public-key }
          readinessProbe:
            httpGet: { path: /actuator/health/readiness, port: http }
            initialDelaySeconds: 10
          livenessProbe:
            httpGet: { path: /actuator/health/liveness, port: http }
            initialDelaySeconds: 30
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: { drop: ["ALL"] }
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        seccompProfile: { type: RuntimeDefault }
