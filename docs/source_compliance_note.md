# Source Compliance Note

最后更新：2026-08-05

本项目当前 demo 使用 `MaterialSource` 抽象组织 Deep Dive 材料，不把产品限定为论文阅读器。

## 材料来源

支持的材料类型：

- 用户登记材料：PDF metadata、本地文件路径、URL、手动材料卡。
- 公开材料：public URL、官方文档、GitHub README、文章、论文平台。
- arXiv：仅作为 public source 示例之一，不作为产品边界。
- Fallback demo material：外部来源不可用时，用明确标注的示例材料保证 demo 可运行。

## 本地数据

当前 demo 中以下信息保存在本地 SQLite：

- 个人情况 / 简历摘要。
- 当前工作或学习计划。
- 领域偏好。
- 材料源偏好。
- 用户登记材料 metadata。

当前阶段不上传真实隐私材料，不保存真实 PDF 内容，不做云端同步。

## 推荐边界

Deep Dive 推荐理由应来自：

- 用户目标和领域偏好。
- 当前计划、本周重点和下一步。
- 用户登记材料或公开材料 metadata。
- 最近 check-in 和历史记录。

系统不应把固定查询词当作产品边界。`tracking keywords seeds` 应来自用户目标和当前计划，并允许后续由用户配置。
