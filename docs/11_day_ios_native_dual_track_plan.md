# 11 天双线并行计划：iOS 原生开发 + 竞赛文档

最后更新：2026-08-06

截止日期：2026-08-16

项目名称：

```text
圆周引擎 / Orbit Engine
```

主线调整：

```text
停止继续扩展 Web 端。
Web 仅保留为后端 API smoke / 兜底演示。
8/06 之后主展示面切回 iOS 原生 App + FastAPI 后端。
```

## 执行原则

- 每天同时推进两条线：开发线 + 文档/PPT/PDF 线。
- 开发线优先保证 iPhone 录屏体验，不再投入 Web 美化。
- 文档线从第 1 天开始持续积累，不等最后三天集中补。
- Deep Dive 是唯一必须做深的闭环；Radar、Weekly Studio、Opportunity Alignment 做轻量可展示。
- Agent 能力要体现为“基于用户上下文组织材料、任务、草稿和下一步”，不是单纯聊天框。

## 交付物

必须交付：

- [ ] iOS 原生 demo 可录屏。
- [ ] FastAPI 后端可启动，支持 iOS 主链路。
- [ ] 60-90 秒 demo 视频。
- [ ] Proposal PPT/PDF。
- [ ] 500 字项目介绍。
- [ ] README / runbook。
- [ ] GitHub 仓库链接。

辅助交付：

- [ ] 架构图。
- [ ] 领域复用映射表。
- [ ] 数据与隐私说明。
- [ ] 当前进度和限制说明。

## 每日计划

### Day 1（2026-08-06）：主线冻结与材料框架

开发线：

- [x] 冻结 Web 扩展，明确 Web 仅保留为 API smoke / 兜底演示。
- [x] 确认 GOAI/iOS 复用 infra 原生 SwiftUI 结构。
- [x] 梳理 iOS 页面迁移范围：Today、History、Research、Chat、Settings、Resume/JD 可复用部分。
- [x] 确认 iOS 底部栏目标：`今日 / 历史 / 计划 / 我的`。
- [x] 列出 Day 2 需要接入的后端 endpoint。

文档 / PPT / PDF 线：

- [ ] 重写项目主叙事：为什么从 Web 切回 iOS。
- [ ] 更新产品定位为 iOS-first mobile Agent。
- [ ] 列出 proposal PPT 必备页面清单。
- [ ] 梳理 60-90 秒 demo 的主链路，不展示 Web。

完成标准：

- [x] 明确 iOS 原生为主展示面。
- [x] 形成 iOS 迁移清单。
- [ ] 形成 PPT 页面目录。

### Day 2（2026-08-07）：iOS 接入 GOAI 后端

开发线：

- [ ] iOS APIClient 指向 GOAI FastAPI backend。
- [ ] iOS 验证 `/api/health`。
- [ ] iOS 验证 `/api/sessions/today`。
- [ ] iOS 验证 `/api/user-context`。
- [ ] Today 能显示 Deep Dive session 标题、状态、推荐理由和日期。
- [ ] Today 能显示用户计划上下文摘要。

文档 / PPT / PDF 线：

- [ ] 写 `problem` 页面草稿：不是缺计划，而是启动成本高。
- [ ] 写 `user` 页面草稿：有长期目标、需要周期性行动和反馈的人。
- [ ] 写 `scenario` 页面草稿：早晨/碎片时间打开 app，直接进入今日 session。
- [ ] 收集 iOS Today 截图占位或草图。

完成标准：

- [ ] iOS Today 能读后端。
- [ ] PPT 前 3 页有文字初稿。

### Day 3（2026-08-08）：iOS Deep Dive 队列与新建入口

开发线：

- [ ] iOS 实现 Deep Dive 队列页。
- [ ] 队列页显示进行中 / 未完成 Deep Dive。
- [ ] 队列页显示 `新建 Deep Dive`。
- [ ] 新建入口包含 PDF metadata。
- [ ] 新建入口包含 URL 登记。
- [ ] 新建入口包含手动材料卡。
- [ ] 新建材料 metadata 可写入后端或本地状态。

文档 / PPT / PDF 线：

- [ ] 写 `core workflow` 页面草稿。
- [ ] 明确 workflow：Today -> Deep Dive -> Material -> Agent Guidance -> Check-in -> History。
- [ ] 整理 demo 录屏脚本 v1。
- [ ] 写清楚“材料源不等于论文源”。

完成标准：

- [ ] iOS 能从 Today 进入 Deep Dive 队列。
- [ ] iOS 能看到新建 Deep Dive 的三种材料入口。
- [ ] 录屏路径 v1 明确。

### Day 4（2026-08-09）：iOS Deep Dive 详情页

开发线：

- [ ] Deep Dive 详情页只保留一个主材料。
- [ ] 显示当前任务。
- [ ] 显示阅读目标。
- [ ] 显示选择理由。
- [ ] 显示 30/60/90 分钟路径。
- [ ] 显示完成标准。
- [ ] 上述信息块不做伪点击入口，避免层级混乱。

文档 / PPT / PDF 线：

- [ ] 写 `Agent capability` 页面草稿。
- [ ] 解释 Agent 如何基于个人情况、计划、材料偏好生成推荐理由。
- [ ] 解释 Agent 如何把材料处理变成下一步行动。
- [ ] 准备一张 Agent 能力流程图草稿。

完成标准：

- [ ] iOS Deep Dive 详情页可展示。
- [ ] Agent 能力叙事成页。

### Day 5（2026-08-10）：iOS Check-in + Agent Guidance

开发线：

- [ ] Check-in 放在完成标准下面的按钮中，不裸露在外层。
- [ ] Agent Guidance 放在完成标准下面的按钮中。
- [ ] Agent Guidance 能生成 Check-in 草稿。
- [ ] 用户可修改 Agent 生成的 Summary。
- [ ] 用户可修改 Agent 生成的 Key insight。
- [ ] 用户可修改 Agent 生成的 Next action。
- [ ] 保存后写入 History。

文档 / PPT / PDF 线：

- [ ] 写 `closed-loop evidence` 页面草稿。
- [ ] 解释 session status 如何变化。
- [ ] 解释 History 如何沉淀 check-in。
- [ ] 解释下一轮 Agent 如何复用历史和计划上下文。

完成标准：

- [ ] 主闭环跑通：Deep Dive -> Agent draft -> Check-in -> History。
- [ ] closed-loop evidence 页面有初稿。

### Day 6（2026-08-11）：iOS 计划 / 我的

开发线：

- [ ] iOS `计划` 页面显示长期目标。
- [ ] iOS `计划` 页面显示本周重点。
- [ ] iOS `计划` 页面显示当前任务。
- [ ] iOS `计划` 页面显示 tracking keywords。
- [ ] iOS `我的` 页面显示个人情况 / 简历摘要。
- [ ] iOS `我的` 页面显示领域偏好。
- [ ] iOS `我的` 页面显示材料源偏好。
- [ ] iOS `我的` 页面显示本地数据说明。

文档 / PPT / PDF 线：

- [ ] 写 `data/context` 页面草稿。
- [ ] 说明用户上下文包含哪些字段。
- [ ] 说明本地记录和隐私边界。
- [ ] 说明材料源类型。
- [ ] 将 `source_compliance_note` 整理为提交材料可用版本。

完成标准：

- [ ] iOS 能解释“Agent 为什么推荐这份材料”。
- [ ] 数据 / 隐私页有初稿。

### Day 7（2026-08-12）：三类轻量 Session + 领域复用表

开发线：

- [ ] Radar 原生轻量入口：当前工作区 + 新建入口。
- [ ] Weekly Studio 原生轻量入口：当前工作区 + 新建入口。
- [ ] Opportunity Alignment 原生轻量入口：当前工作区 + 新建入口。
- [ ] 三类页面显示 `Agent 能做什么`。
- [ ] 不做完整 CRUD。

文档 / PPT / PDF 线：

- [ ] 写 `domain mapping table` 独立页。
- [ ] 映射职业能力建设。
- [ ] 映射研究方向探索。
- [ ] 映射创作者 / 视觉 IP 运营。
- [ ] 映射创业 / 产品探索。
- [ ] 映射语言学习。

完成标准：

- [ ] 四类 session 在 iOS 可见。
- [ ] 领域复用映射表完成。

### Day 8（2026-08-13）：调试冻结 + Proposal Draft

开发线：

- [ ] 解决 iPhone / Appetize / 模拟器调试链路。
- [ ] 修复 iOS 编译阻塞。
- [ ] 修复接口状态错误。
- [ ] 修复主要布局问题。
- [ ] 冻结主 demo path。
- [ ] 录一轮内部调试视频。

文档 / PPT / PDF 线：

- [ ] 合并 proposal draft。
- [ ] 加入封面。
- [ ] 加入问题、用户、workflow。
- [ ] 加入 Agent 架构。
- [ ] 加入 domain mapping。
- [ ] 加入当前进度、限制和 roadmap。

完成标准：

- [ ] iOS 可录屏候选版本形成。
- [ ] PPT/PDF draft v1 完成。

### Day 9（2026-08-14）：Dry Run + 项目介绍

开发线：

- [ ] 从 clean start 启动后端。
- [ ] 从 iPhone / Appetize 打开 iOS demo。
- [ ] 完整跑一次录屏路径。
- [ ] 记录所有阻塞 bug。
- [ ] 只修影响录屏闭环的 blocker。
- [ ] 不新增功能。

文档 / PPT / PDF 线：

- [ ] 根据 dry run 更新 PPT 截图。
- [ ] 根据 dry run 更新视频脚本。
- [ ] 写 500 字项目介绍初稿。
- [ ] 写 known limitations 初稿。

完成标准：

- [ ] dry-run 视频可跑完。
- [ ] 500 字介绍 v1 完成。

### Day 10（2026-08-15）：最终视频 + 材料候选版

开发线：

- [ ] 冻结代码。
- [ ] 修少量展示级 bug。
- [ ] 录制 iPhone 竖屏 60-90 秒最终候选视频。
- [ ] 确认视频路径和 PPT 叙事一致。

文档 / PPT / PDF 线：

- [ ] 导出 proposal final candidate PDF。
- [ ] 整理 README。
- [ ] 整理 demo runbook。
- [ ] 整理 GitHub 提交说明。
- [ ] 整理 limitations / roadmap。

完成标准：

- [ ] demo video candidate 完成。
- [ ] proposal PDF candidate 完成。
- [ ] README / runbook 完成。

### Day 11（2026-08-16）：提交冻结

开发线：

- [ ] 不再做功能开发。
- [ ] 只修运行阻塞。
- [ ] 确认后端可启动。
- [ ] 确认 iOS 录屏材料与代码状态一致。
- [ ] 确认 GitHub 仓库可访问。

文档 / PPT / PDF 线：

- [ ] 最终确认 PPT/PDF。
- [ ] 最终确认 500 字介绍。
- [ ] 最终确认视频链接/文件。
- [ ] 最终确认 GitHub 链接。
- [ ] 最终确认数据合规说明。
- [ ] 最终确认当前进度说明。

完成标准：

- [ ] 完成提交。
- [ ] 不遗留关键路径事项。

## 开发线范围

必须做：

- [ ] iOS 原生 Today 能连接 GOAI/FastAPI 后端。
- [ ] iOS 原生 Deep Dive 队列页。
- [ ] iOS 原生新建 Deep Dive：PDF metadata / URL / 手动材料卡。
- [ ] iOS 原生 Deep Dive 详情页：一个主材料 + 推荐理由 + 时间路径 + 完成标准。
- [ ] iOS 原生 Agent Guidance：生成 Check-in 草稿。
- [ ] iOS 原生 Check-in：用户可修改并写入 History。
- [ ] iOS 原生 History 显示完成记录。
- [ ] iOS 原生计划/我的展示用户上下文。

轻量做：

- [ ] Radar 当前工作区 + 新建入口。
- [ ] Weekly Studio 当前工作区 + 新建入口。
- [ ] Opportunity Alignment 当前工作区 + 新建入口。
- [ ] Agent 能做什么的解释页。

明确不做：

- [ ] Web 端继续美化。
- [ ] 完整 PDF annotation。
- [ ] 完整公开源抓取。
- [ ] 完整 JD/Opportunity CRUD。
- [ ] 多用户、登录、云同步。
- [ ] 原生复杂图表或高级动画。

## 文档 / PPT / PDF 线范围

PPT/PDF 建议页：

1. 封面：圆周引擎 / Orbit Engine。
2. 问题：不是缺计划，而是每天启动学习/探索的摩擦太高。
3. 用户：有长期目标、需要周期性行动和反馈的人。
4. 产品定义：周期性 Agent session，而不是 todo app。
5. 核心 workflow：Today -> Deep Dive -> Agent Guidance -> Check-in -> History。
6. Agent 能力：根据用户上下文组织材料、任务、草稿和下一步。
7. 四类 session：Radar / Deep Dive / Weekly Studio / Opportunity Alignment。
8. 领域复用映射表：独立页。
9. 系统架构：iOS SwiftUI + FastAPI + SQLite + session payload。
10. 数据与隐私：本地上下文、材料 metadata、无云同步。
11. 当前进度：已完成和 8/16 demo 范围。
12. 限制与 roadmap：真实文件上传、公开源抓取、多领域模板、云同步。

必须写清：

- [ ] 为什么不是 todo app。
- [ ] 为什么不是论文阅读器。
- [ ] 为什么不是单纯打卡工具。
- [ ] Agent 在哪里产生价值。
- [ ] 8/16 demo 的边界是什么。
- [ ] 哪些是已实现，哪些是 roadmap。

## Demo 视频脚本范围

60-90 秒只展示一条主链：

```text
打开 iOS app
-> Today 显示今天推荐的 Deep Dive
-> 进入 Deep Dive 队列
-> 新建或打开一个 Deep Dive
-> 展示主材料和推荐理由
-> 打开 Agent Guidance，生成 Check-in 草稿
-> 用户确认/微调 Check-in
-> 写入 History
-> 简短切到计划/我的，说明 Agent 推荐来自用户上下文
```

不要在视频里展开：

- 完整 Radar。
- 完整 Weekly Studio。
- 完整 Opportunity Alignment。
- Web 页面。
- 复杂设置。
- 开发调试过程。

## 每日更新规则

每天完成任务后必须更新：

- [ ] 本文档对应日期的 checklist / 状态。
- [ ] `docs/13_day_competition_plan.md` 的进度记录，如果任务属于既有计划项。
- [ ] `memory/PROJECT_MEMORY.md`，如果发生产品方向、架构或交付策略变化。

## Progress Log

### 2026-08-06

- [x] 在 GOAI 中创建竞赛专用分支 `competition/ios-native-boundless`。
- [x] 从 `/home/maxh/Agent/infra` 同步原生 iOS / FastAPI 代码基线到 `/home/maxh/Agent/GOAI`，未修改 infra 原目录。
- [x] 冻结 Web 端扩展，明确 Web 仅作为 API smoke / 兜底演示。
- [x] 确认 8/16 主展示面改为 iOS 原生 SwiftUI App + FastAPI。
- [x] 创建 iOS 迁移清单：`docs/ios_native_migration_checklist.md`。
- [x] 明确目标底部栏：`今日 / 历史 / 计划 / 我的`。
- [x] 明确 Day 2 优先验证 endpoint：`/api/health`、`/api/sessions/today`、`/api/user-context`。
