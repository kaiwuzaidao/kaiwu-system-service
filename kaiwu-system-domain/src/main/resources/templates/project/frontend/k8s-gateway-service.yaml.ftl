apiVersion: v1
kind: Service
metadata:
  name: kaiwu-platform-gateway
spec:
  type: ExternalName
  # 默认平台 Helm release=kaiwu、namespace=kaiwu；GitOps Application 可按环境覆盖。
  externalName: kaiwu-kaiwu-gateway.kaiwu.svc.cluster.local
  ports:
    - name: http
      port: 8088
      targetPort: 8088
