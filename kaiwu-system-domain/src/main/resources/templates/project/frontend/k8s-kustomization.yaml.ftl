apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - gateway-service.yaml
  - ingress.yaml
images:
  - name: kaiwu-${projectCode}-web
    newName: registry.example.com/kaiwu-${projectCode}-web
    newTag: replace-me
