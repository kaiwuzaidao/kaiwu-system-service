# ${projectName}的参数配置清单（ADR 0036）。只声明键、类型和默认值；运行值由运维在平台里维护，
# 同步不会覆盖已有值。含 password / secret / token / key 的键会被拒绝，密钥不要写进仓库。
#
# - key: ${projectCode}.page_size
#   type: NUMBER
#   default: 20
#   description: 列表默认每页条数
[]
