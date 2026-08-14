# Orbit Engine Proposal PPT Review

最后更新：2026-08-06

对应文件：

- `submission/orbit_engine_proposal.pptx`
- 原始文件：`/home/maxh/Agent/GOAI/orbit_engine_proposal.pptx`

## 1. 当前项目状态

`/home/maxh/Agent/GOAI` 当前是 GOAI 无界应用赛道的参赛项目工作区，产品名为：

```text
圆周引擎 / Orbit Engine
```

当前定位：

```text
面向成人职业能力建设和专业领域持续探索的周期性行动 Agent。
```

项目不是完整个人 Infra Agent 的全部功能，而是从个人 Infra Agent 中抽取出的参赛版本。

最新主线已经在 2026-08-06 调整：

```text
iOS 原生 App 作为主 demo 展示面
FastAPI 后端作为 session / material / check-in / history 的动作与数据层
Web 仅保留为 backend smoke / fallback demo，不再作为主展示面
```

已完成基础：

- FastAPI 后端结构。
- `BaseSession` 数据模型。
- Weekly Coordinator 节奏路由。
- Check-in / History 基础闭环。
- JD Intelligence MVP。
- Web fallback 端到端 mock 闭环：`Today -> Deep Dive Workspace -> Check-in -> History`。
- `MaterialSource` / user context 基础支持：
  - PDF metadata / local path。
  - URL。
  - manual material card。
  - public source。
  - fallback demo material。
- `/api/user-context` 和 `/api/user-context/materials`。

当前风险：

- iOS 主链路仍在接入 GOAI 后端。
- PPT 仍有明显 Web-first / arXiv-first 旧叙事。
- Proposal 截图还未换成最终 iOS 原生 demo 截图。
- Live arXiv/public source adapter 尚未完成，且不应作为产品核心边界。

## 2. PPT 当前结构

当前 PPT 共 11 页：

1. 封面：圆周引擎 / Orbit Engine，AI + Education。
2. 问题：阻力不是缺计划，而是启动前决策和筛选成本。
3. 目标用户：职业方向探索期技术从业者，一周节奏。
4. 解决方案：Scheduled / Manual + 六步闭环 + 四类 session。
5. 通用性：四类 session 映射到职业、研究、创作者、创业等领域。
6. Agent 能力：Deep Dive 对应 closed-loop 七环节。
7. 数据与技术路线：FastAPI、SQLite、Web、OpenRouter、arXiv、合规。
8. Demo 成果：Today -> Deep Dive -> Check-in -> History，截图待补。
9. 安全与合规：不替代决策、不自动外部动作、来源可追溯、Demo Mode。
10. 当前进展：已完成 / 进行中 / 规划中。
11. 开源与展望：抽象层、模板、Web demo 脚本、未来规划。

整体结构方向是对的：

```text
问题 -> 用户 -> 方案 -> 通用性 -> Agent 能力 -> 技术 -> Demo -> 合规 -> 进展 -> 展望
```

但当前最大问题不是细节不足，而是主叙事没有跟上项目最新路线。

## 3. 必须修改

### 3.1 全局改掉 Web-first 叙事

当前第 7、8、10、11 页仍出现：

```text
Mobile-first Web
Mobile-first Web Demo
Web Demo 部署脚本
原生 iOS 并行演进
```

这与 2026-08-06 之后的项目主线冲突。

建议统一改成：

```text
iOS Native App as primary demo surface
FastAPI backend as session/action runtime
Web demo retained only for API smoke and fallback
```

中文可写：

```text
iOS 原生 App 是主展示面，FastAPI 后端承载 session、材料、打卡和历史数据。
Web 仅保留为后端 smoke 和 fallback demo，不作为参赛主展示面。
```

### 3.2 弱化 arXiv，强化 MaterialSource

当前第 6、7、8 页把 arXiv 写得过于核心，容易让评委误解为“论文阅读器”。

最新产品边界应该是：

```text
MaterialSource: user-registered PDF metadata / URL / manual card / public source / fallback demo material
arXiv is one optional public source, not the product boundary
```

中文可写：

```text
Deep Dive 不绑定单一论文平台，而是通过 MaterialSource 抽象接入用户材料和公开材料。
arXiv 只是 public source 的一个可选示例，不是产品边界。
```

### 3.3 第 8 页 Demo 成果改成 iOS 主链路

当前标题：

```text
Mobile-First Web Demo
完整闭环：Today -> Deep Dive Workspace -> Check-in -> History
```

建议改成：

```text
iOS Native Demo
完整闭环：Today -> Deep Dive Queue -> Material -> Agent Guidance -> Check-in -> History
```

最终截图应使用 iOS 原生 demo 截图。

当前已有 Web/iOS-style mock 截图可以临时占位，但最终提交前建议替换为 Day 8 之后冻结的 iOS 录屏截图。

### 3.4 第 10 页当前进展重写

当前“进行中：Deep Dive × arXiv 真实数据源接入”已经不是主线。

建议改成：

已完成：

- FastAPI session / check-in / history。
- `BaseSession` 与 Weekly Coordinator。
- `MaterialSource` / user context。
- Web fallback closed loop。
- JD Intelligence MVP。

进行中：

- iOS 接入 GOAI FastAPI backend。
- iOS Today / Deep Dive / Check-in / History 主链路。
- Agent Guidance 生成 check-in draft。
- iOS 录屏路径冻结。

规划中：

- Radar / Weekly Studio / Opportunity Alignment 轻量展示。
- README / runbook。
- 60-90 秒 demo video。
- Proposal PDF。
- 多领域模板配置。

### 3.5 统一“六步闭环”和“七环节”

第 4 页写六步闭环，第 6 页写七个环节，表达不统一。

建议统一为：

```text
Input -> Intent -> Planning -> Source/Tool Invocation -> Result Delivery -> User Feedback -> Memory/Next Cycle
```

中文：

```text
输入 -> 意图理解 -> 任务规划 -> 材料/工具调用 -> 结构化交付 -> 用户反馈 -> 记忆与下一周期
```

这样也更贴近 Boundless Agents 对 Agent 闭环能力的评价。

## 4. 建议优化

### 4.1 封面副标题更聚焦

当前：

```text
面向任意专业领域的周期性成长 Agent
```

建议改为：

```text
面向成人职业能力建设的周期性行动 Agent
```

或：

```text
把分散材料转化为每日可执行 session 的职业成长 Agent
```

理由：

- “任意专业领域”太泛。
- “成长 Agent”偏抽象。
- “职业能力建设”和“每日可执行 session”更贴合 AI + Education / Vocational Education。

### 4.2 问题页增加具体使用场景

当前问题讲得对，但偏概念。

建议增加一个更具体的链路：

```text
早上只有 45 分钟
-> 不知道今天该看论文、repo、JD 还是行业信号
-> 搜索和筛选耗掉时间
-> 没有形成 check-in 和下一步
```

这能把“启动成本”讲得更真实。

### 4.3 用户页避免过度个人化

“非跳槽窗口期”很真实，但 proposal 面向评委时可以泛化。

建议写成：

```text
有长期职业目标，但当前时间碎片化、外部机会窗口不稳定，需要持续积累能力证据的人。
```

这样既保留真实用户洞察，又不会让产品看起来只服务一个人。

### 4.4 通用性页不要抢主 demo

第 5 页通用性表格可以保留，这是产品抽象能力。

但建议在页脚加：

```text
本次 demo 只完整实现 AI / Autonomous Driving Research 下的 Deep Dive 闭环。
其他领域通过同一套 Session Type 和 MaterialSource 抽象复用。
```

这样评委不会误以为四条线都已经完整实现。

### 4.5 技术路线页改成架构图

第 7 页当前文字较多，建议改成三层架构：

```text
iOS App
  -> FastAPI Session Runtime
  -> SQLite Local Store + MaterialSource + LLM Adapter
```

旁边列关键 API：

```text
GET  /api/sessions/today
GET  /api/user-context
POST /api/user-context/materials
POST /api/sessions/{session_id}/completion/confirm
GET  /api/checkins
```

### 4.6 安全合规页补“本地优先”

建议补充：

```text
Personal context and material metadata are stored locally in SQLite in the demo.
No automatic resume delivery, no job application, no hidden external action.
```

中文：

```text
Demo 阶段个人上下文和材料 metadata 存储在本地 SQLite。
系统不自动投递简历、不自动申请岗位、不执行隐藏外部动作。
```

## 5. 建议新增或替换页面

如果页数允许，建议从 11 页扩到 12-13 页。

### 5.1 新增：Why Agent, Not Todo

目的：

清楚区分 Orbit Engine 与 todo app、阅读器、chatbot。

建议表格：

| 类型 | 用户负担 | 是否理解材料 | 是否形成行动 | 是否沉淀历史 |
| --- | --- | --- | --- | --- |
| Todo app | 用户自己定义任务 | 否 | 弱 | 只记录完成 |
| Reader / Bookmark | 用户自己筛选材料 | 部分 | 否 | 弱 |
| Chatbot | 用户自己发起问题 | 取决于输入 | 不稳定 | 弱 |
| Orbit Engine | Agent 准备今日 session | 是 | 是 | 是 |

### 5.2 新增：核心数据对象

建议展示：

```text
UserContext
MaterialSource
BaseSession
CompletionState
Check-in
History
```

目的：

让 proposal 看起来不是 UI mock，而是有清楚的数据结构和 Agent runtime。

### 5.3 新增或替换：Demo Path

建议展示 iOS 主链路：

```text
Today
-> Deep Dive Queue
-> Material
-> Agent Guidance
-> Editable Check-in
-> History
```

这一页应配最终 iOS 截图。

## 6. 页面级修改建议

### Slide 1：封面

保留：

- 圆周引擎 / Orbit Engine。
- AI + Education / Vocational Education。

修改：

- 副标题改得更具体。
- 团队成员占位 `[姓名]` 后续要补真实提交名或团队名。

### Slide 2：问题

保留：

- “阻力不是缺计划，而是启动前决策和筛选成本”。

优化：

- 加入早晨 30-60 分钟的具体行动场景。
- “30-60 分钟花在决策上”如果没有真实调研数据，建议写成“典型碎片时间窗口”而不是定量结论，避免被追问来源。

### Slide 3：目标用户

保留：

- 成人技术从业者。
- 周节奏。

优化：

- 将“非跳槽窗口期”泛化为“外部机会窗口不稳定”。
- 保留旗舰场景，但不要让它显得只服务自动驾驶个人研究。

### Slide 4：解决方案

保留：

- Scheduled Mode / Manual Mode。
- 四类 session。

修改：

- 六步闭环改成统一七环节，或全 PPT 保持六步。
- 建议把 `Agent 讨论反馈` 改成更准确的 `Agent Guidance / Check-in Draft`。

### Slide 5：通用性

保留：

- 四类 session 的领域映射。

优化：

- 增加“本次 demo 只完整实现旗舰场景 Deep Dive 闭环”的边界说明。
- Weekly Studio 不单列是合理的，但页脚说明应简短。

### Slide 6：Agent 能力

必须修改：

- `Capability Invocation` 不要只写 arXiv。

建议改为：

```text
Capability Invocation:
读取 MaterialSource / user context / history，必要时调用 public source 或 LLM adapter。
```

### Slide 7：数据与技术路线

必须修改：

- `Mobile-first Web` 改为 `iOS Native App`。
- `arXiv` 改为 `MaterialSource`。
- OpenRouter 表达要谨慎：当前 OpenRouter 主要在 JD Intelligence 中较完整，Deep Dive guidance 如果未完全接入，不要写成已完成。

建议结构：

```text
Presentation Layer:
iOS Native App, Web fallback for smoke

Runtime Layer:
FastAPI, BaseSession, Weekly Coordinator, Completion confirm

Data/Context Layer:
SQLite, UserContext, MaterialSource, Check-in, History

Model/Agent Layer:
LLM adapter for structured analysis and guidance draft, fallback Demo Mode
```

### Slide 8：Demo 成果

必须修改：

- 改为 iOS Native Demo。
- 截图待补应换成 iOS 页面截图。

建议四格：

```text
Today
Deep Dive Queue / Material
Agent Guidance + Check-in
History
```

### Slide 9：安全与合规

保留：

- 不替代用户决策。
- 不自动执行外部动作。
- Demo Mode 标注。

补充：

- 本地 SQLite。
- 用户自主提供材料。
- public source 可追溯。

### Slide 10：当前进展

必须重写，按最新 11 天计划同步。

### Slide 11：开源与展望

修改：

- `Mobile-first Web Demo 部署脚本` 改为：

```text
FastAPI backend runbook
iOS demo path documentation
Web smoke/fallback demo
```

展望中可以写：

```text
原生 iOS 主体验持续完善，Web 作为调试和跨端 fallback。
```

## 7. 修改优先级

优先级从高到低：

1. 全局替换 Web-first 为 iOS-first。
2. 将 arXiv-first 改为 MaterialSource-first。
3. 重写第 7 页技术路线。
4. 重写第 8 页 Demo 成果。
5. 重写第 10 页当前进展。
6. 统一 closed-loop 表述。
7. 补 iOS 截图。
8. 补 Why Agent, Not Todo / 核心数据对象 / Demo Path 页面。
9. 最后做文字压缩和视觉排版。

## 8. 建议的新 PPT 目录

推荐版本：

1. Cover：圆周引擎 / Orbit Engine。
2. Problem：启动成本，而不是缺资源。
3. Target User：成人职业能力建设用户。
4. Product Logic：Scheduled + Manual。
5. Core Workflow：Today -> Deep Dive -> Agent Guidance -> Check-in -> History。
6. Why Agent, Not Todo。
7. Session Types：Radar / Deep Dive / Opportunity Alignment / Weekly Studio。
8. Domain Mapping：多领域复用。
9. Agent Closed Loop：Input -> Intent -> Planning -> Source -> Delivery -> Feedback -> Memory。
10. Architecture：iOS + FastAPI + SQLite + MaterialSource + LLM Adapter。
11. Data & Safety：local-first、public/user-provided source、no hidden action。
12. Demo Evidence：iOS screenshots。
13. Progress & Roadmap：已完成 / 进行中 / 下一步。

如果必须控制在 10-11 页：

- 合并 `Session Types` 和 `Domain Mapping`。
- 合并 `Data & Safety`。
- 合并 `Demo Evidence` 和 `Progress`。

## 9. 一句话判断

当前 PPT 的骨架可以保留，但它现在不是简单补细节的问题，而是主叙事还停留在旧路线。

应先修正：

```text
Web-first -> iOS-first
arXiv-first -> MaterialSource-first
论文阅读器印象 -> 职业能力建设 Agent
UI demo -> 有 session runtime / user context / check-in memory 的 Agent 闭环
```

修完这些，后续再补截图、架构图和视觉细节，proposal 才会和真实开发进度一致。
