apiVersion: v1
kind: Service
metadata:
  name: kaiwu-${projectCode}-web
spec:
  selector:
    app: kaiwu-${projectCode}-web
  ports:
    - name: http
      port: 8080
      targetPort: http
