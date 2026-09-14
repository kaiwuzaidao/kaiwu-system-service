# 本仓库的镜像命名。只放"叫什么"，不放"推到哪个地址"——
# HARBOR_REGISTRY / HARBOR_USER / HARBOR_PASSWORD 由 CI 变量提供，
# 这样同一份源码在任何组织、任何镜像仓库下都能直接用。
APP_NAME=kaiwu-${projectCode}-web
HARBOR_PROJECT=kaiwu
