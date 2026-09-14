apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
images:
  - name: kaiwu-${projectCode}-service
    newName: registry.example.com/kaiwu-${projectCode}-service
    newTag: replace-me
