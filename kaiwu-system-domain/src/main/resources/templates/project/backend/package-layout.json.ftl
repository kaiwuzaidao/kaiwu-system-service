{
  "version": 1,
  "profile": "business",
  "basePackage": "${basePackage}",
  "categories": [<#list layoutCategories as item>"${item}"<#sep>, </#sep></#list>],
  "layers": ["controller", "service", "repository", "mapper", "entity", "convert", "agent", "adapter", "config", "client", "dto", "vo", "model", "exception"],
  "compatibilityTypes": [],
  "concreteServiceHelpers": [],
  "sourceRoots": ["kaiwu-${projectCode}-api/src/main/java", "kaiwu-${projectCode}-domain/src/main/java", "kaiwu-${projectCode}-boot/src/main/java"]
}
