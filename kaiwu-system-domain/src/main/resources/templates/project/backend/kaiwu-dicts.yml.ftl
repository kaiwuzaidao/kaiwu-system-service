# ${projectName}的受管字典清单（ADR 0036）。
# 用 `./kaiwu project sync <本仓路径>` 查看计划、加 --apply 写入平台；只新增、不删除。
#
# 脚手架不会替你猜业务枚举，所以初始为空。需要时参考下面的示例，改成自己的枚举后取消注释：
#
# - dictCode: ${projectCode}.record_status
#   name: 记录状态
#   items:
#     - value: PENDING
#       label: 待处理
#       color: processing
#       default: true
#     - value: DONE
#       label: 已完成
#       color: success
#     - value: CANCELLED
#       label: 已取消
#       color: default
#
# 约定：颜色只用语义色（success/error/processing/warning/default），纯分类不着色。
[]
