apiVersion: v1
kind: Service
metadata:
  name: kaiwu-${projectCode}-service
spec:
  selector:
    app: kaiwu-${projectCode}-service
  ports:
    - name: http
      port: 8080
      targetPort: http
