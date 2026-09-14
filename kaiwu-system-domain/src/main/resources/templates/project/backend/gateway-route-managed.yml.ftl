- id: ${projectCode}-project
  uri: http://kaiwu-${projectCode}-service:8080
  predicates:
    - Path=/${projectCode}-api/**
  filters:
    - RewritePath=/${projectCode}-api/(?<segment>.*), /${r"${segment}"}
  metadata:
    accessMode: PROJECT
    audience: kaiwu-${projectCode}-service
    projectCode: ${projectCode}
