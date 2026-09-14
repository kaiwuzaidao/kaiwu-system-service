apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kaiwu-${projectCode}
spec:
  rules:
    - host: kaiwu.example.com
      http:
        paths:
          - path: /apps/${projectCode}/
            pathType: Prefix
            backend:
              service:
                name: kaiwu-${projectCode}-web
                port: { number: 8080 }
          # 只访问同 namespace 的 Gateway 别名；别名指向平台 Gateway 的完整集群域名。
          - path: /${projectCode}-api/
            pathType: Prefix
            backend:
              service:
                name: kaiwu-platform-gateway
                port: { number: 8088 }
