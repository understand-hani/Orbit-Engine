# iOS 原生迁移清单

最后更新：2026-08-06

## 当前原则

- `/home/maxh/Agent/infra` 是个人自用 Infra Agent 工程，后续只作为只读参考源。
- `/home/maxh/Agent/GOAI` 是竞赛工程，当前分支为 `competition/ios-native-boundless`。
- Web 端停止继续扩展，只保留为 FastAPI smoke / 兜底演示，不再作为主展示面。
- 8 月 16 日前主展示面锁定为 iOS 原生 SwiftUI App + FastAPI 后端。
- Deep Dive 是唯一需要做深的完整闭环；Radar、Weekly Studio、Opportunity Alignment 做轻量可展示。

## 已迁移代码基线

从 `infra` 同步到 `GOAI`：

- `backend/`
- `ios/`
- `README.md`
- `codemagic.yaml`

同步策略：

- 不修改 `infra` 原目录。
- 不同步 `backend/.env`。
- 不同步 `data/` 本地数据库。
- 不同步 Python cache / virtualenv。
- 保留 GOAI 竞赛专用文件：`docs/`、`memory/`、`submission/`、`web/`。
- 保留 GOAI 竞赛专用后端增量：`/api/user-context` 和材料登记相关文件。

## 目标底部栏

8 月 16 日 demo 的 iOS 底部栏应调整为：

- `今日`
  - 入口页。
  - 默认展示 Scheduled Mode。
  - 可切换 Manual Mode。
  - 显示当天 session 卡片，不在首页暴露完整 workspace 内容。
- `历史`
  - 展示 check-in、session 状态、已完成记录。
  - 用于证明闭环沉淀。
- `计划`
  - 管理长期目标、本周重点、当前任务、tracking keywords。
  - 为 Agent 推荐材料和任务提供上下文来源。
- `我的`
  - 折叠原 Settings。
  - 管理个人情况 / 简历摘要、材料源偏好、隐私与本地数据说明。

需要从主 Tab 折叠或移除：

- `收件箱`：不作为主 Tab，材料入口并入 Deep Dive / Radar workspace。
- `JD`：不作为主 Tab，作为 Opportunity Alignment 的一种来源或子流程。
- `更多`：改造为 `我的`。

## Session 映射

- `Radar`
  - 旧实现参考：`tech-radar-feeder` / `TechRadarView`。
  - 8/16 范围：轻量 workspace，展示信号、推荐理由、下一步。
- `Deep Dive`
  - 旧实现参考：`research-feeder` / `ResearchReaderView` / PDF reader 相关页面。
  - 8/16 范围：主闭环，包含材料选择、任务路径、Agent Guidance、Check-in、History。
- `Opportunity Alignment`
  - 旧实现参考：`jd` / `JDIntelligenceView`。
  - 8/16 范围：轻量展示，不做完整 JD Intelligence CRUD。
- `Weekly Studio`
  - 新增 session 类型。
  - 8/16 范围：轻量展示周复盘、归档、计划更新、下一周选择。

## iOS 可复用范围

- `TodayView`
  - 复用加载今日 session、打开工作区的结构。
  - 需要改成 Scheduled / Manual segmented control。
  - 首页只放 session 卡片和少量上下文摘要。
- `SessionDestinationView`
  - 复用 task type 路由思想。
  - 需要增加 `Weekly Studio` 路由。
  - 需要把 JD 路由改成 Opportunity Alignment 语义。
- `ResearchReaderView`
  - 作为 Deep Dive 详情页基础。
  - 需要从“论文阅读”改成“通用材料处理”。
  - 保留 PDF / passage / figure 等有价值结构，但避免强绑定论文。
- `AgentChatView`
  - 作为 Agent Guidance 入口。
  - 不裸露在所有卡片里，只在完成标准附近作为按钮进入。
- `CheckinFormView`
  - 作为 Check-in 表单基础。
  - 需要支持 Agent Guidance 生成草稿后由用户修改。
- `HistoryView`
  - 复用为闭环证据页。
  - 需要展示 session 状态变化和 check-in 结果。
- `JDIntelligenceView`
  - 作为 Opportunity Alignment 参考，不直接放主 Tab。
  - 本阶段只迁移机会库 / 候选行动 / 对齐建议的轻量表达。
- `SettingsView` / `MoreView` / `ResumeView`
  - 合并到 `我的`。
  - `ResumeView` 的个人信息能力用于通用“个人情况 / 能力资产”管理。

## Day 2 后端 Endpoint 清单

Day 2 必须先验证：

- `GET /api/health`
  - 用于 iOS 判断后端连接是否正常。
- `GET /api/sessions/today`
  - Today Scheduled Mode 的核心入口。
- `GET /api/user-context`
  - 读取用户目标、计划、材料偏好和当前上下文摘要。

Day 2 可以顺手接入，但不作为当天 blocker：

- `POST /api/user-context/materials`
  - 登记用户自带 PDF metadata、URL 或手动材料。
- `GET /api/sessions/by-date`
  - History / 日历回看。
- `POST /api/sessions/{session_id}/completion/confirm`
  - Session 完成状态确认。
- `GET /api/checkins`
  - History 展示 check-in 记录。

后续再接：

- Chat / Agent Guidance 相关 API。
- Deep Dive 材料详情 API。
- Radar / Opportunity Alignment / Weekly Studio 的轻量 workspace API。

## Day 2 开发入口

- 调整 `RootTabView` 为 `今日 / 历史 / 计划 / 我的`。
- 新增或复用 Swift model/API service 读取 `UserContext`。
- 让 Today 读取 `/api/sessions/today` 与 `/api/user-context`。
- 不继续改 Web UI。
- 不在 Day 2 开始做大规模视觉重设计，先保证 iOS 原生链路能读后端。
