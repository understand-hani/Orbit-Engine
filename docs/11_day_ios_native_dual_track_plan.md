# 11 天双线并行计划：iOS 原生开发 + 竞赛文档

最后更新：2026-08-13

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
- [x] 确认 iOS 底部栏目标：`今日 / 归档 / 计划 / 我的`。
- [x] 列出 Day 2 需要接入的后端 endpoint。

文档 / PPT / PDF 线：

- [ ] 重写项目主叙事：为什么从 Web 切回 iOS。
- [ ] 更新产品定位为 iOS-first mobile Agent。
- [x] 列出 proposal PPT 必备页面清单。
- [ ] 梳理 60-90 秒 demo 的主链路，不展示 Web。

完成标准：

- [x] 明确 iOS 原生为主展示面。
- [x] 形成 iOS 迁移清单。
- [x] 形成 PPT 页面目录。

### Day 2（2026-08-07）：iOS 接入 GOAI 后端

开发线：

- [x] iOS APIClient 指向 GOAI FastAPI backend。
- [x] 默认后端 URL 改为 `https://continuous-ranges-contacted-licence.trycloudflare.com`。
- [x] 保留后端 URL 可配置能力，不把 tunnel 完全写死；优先继续使用 `UserDefaults` / 设置页覆盖。
- [x] iOS 验证 `/api/health`。
- [x] iOS 验证 `/api/sessions/today`。
- [x] iOS 验证 `/api/user-context`。
- [x] iOS Today 顶部实现 Scheduled / Manual 入口，交互参考已完成 Web demo。
- [x] Scheduled 默认展示今天推荐的 session。
- [x] Manual 展示四个条目入口：Radar、Deep Dive、Weekly Studio、Opportunity Alignment。
- [x] 四个条目入口点击后能生成 / 切换对应 workspace 入口卡片，先保持轻量。
- [x] iOS 底部栏改为 `今日 / 归档 / 计划 / 我的`。
- [x] 取消底部独立 `JD` 栏；JD 只作为 Opportunity Alignment 的一种旧实现映射。
- [x] 原 `设置` 并入 `我的`。
- [x] Today 能显示 Deep Dive session 标题、状态、推荐理由和日期。
- [x] Today 能显示用户计划上下文摘要。

文档 / PPT / PDF 线：

- [x] 写 `problem` 页面草稿：不是缺计划，而是启动成本高。
- [x] 写 `user` 页面草稿：有长期目标、需要周期性行动和反馈的人。
- [x] 写 `scenario` 页面草稿：早晨/碎片时间打开 app，直接进入今日 session。
- [ ] 收集 iOS Today 截图占位或草图。

完成标准：

- [x] iOS Today 能读后端。
- [x] iOS 首页具备 Scheduled / Manual 两种入口。
- [x] iOS Manual 能看到四类 session 入口。
- [x] iOS 底部栏变为 `今日 / 归档 / 计划 / 我的`。
- [x] 后端默认 URL 已更新，同时仍可被用户配置覆盖。
- [x] PPT 前 3 页有文字初稿。

### Day 3（2026-08-08）：iOS Deep Dive 队列与新建入口

开发线：

- [x] iOS 实现 Deep Dive 队列页。
- [x] 队列页显示进行中 / 未完成 Deep Dive。
- [x] 队列中的同类 session 显示编号和日期，避免多个未完成项无法区分。
- [x] 队列页显示 `新建 Deep Dive`。
- [x] Deep Dive 队列中的进行中 / 未完成卡片支持 iOS 原生左滑删除，而不是右侧常驻删除按钮。
- [x] 删除 Deep Dive session 优先改为 `skipped` / `archived` 语义，而不是直接硬删除；当前如果先继续硬删除，需要补后端状态化移除接口。
- [x] 如果当天 scheduled Deep Dive 已完成归档，从 Today / Schedule 进入后，进行中 / 未完成列表不应自动回填该 completed session。
- [x] 如果当天 scheduled Deep Dive 已完成归档，空列表状态中仍应提供明确的 `新建一个 Deep Dive` 入口，避免用户不知道如何继续。
- [x] `新建 Deep Dive` 需要避免因为已完成 session 占用日期或本地去重，导致点击后“看起来没反应”。
- [x] Deep Dive 工作区新增 `材料生成` 入口。
- [ ] 修复 Deep Dive 暂存标题一致性：进行中 / 未完成卡片无论序号是 `-1`、`-2` 还是更大，暂存后在归档页 `暂存` 区必须显示同一个 `session.title` 和原序号；不能 fallback 成 `Deep Dive-日期-1`，也不能在移动状态时重新命名。
- [x] 材料生成入口支持 Agent 检索、URL 登记、个人上传三类来源的前端选择。
- [x] Agent 检索支持 `Agent 自动生成` 和 `输入检索主题` 两种模式。
- [x] 材料生成结果可写入现有 `/api/user-context/materials`。
- [x] `材料生成` 先返回候选材料卡片，再由用户点选确认后进入研究页；不要一生成就直接落进研究详情。
- [x] Agent 检索默认提供 2-3 个候选材料；URL / 特定 PDF 来源默认只生成 1 个候选材料卡片。
- [x] 材料确认后，Deep Dive 研究页应只显示“已确认材料”，材料生成入口卡片直接消失，避免入口和结果同时存在。
- [x] 已确认材料状态需要持久化到后端 session / selection state，避免退出后重新进入又回到未确认状态。
- [!] PDF 二进制上传、真实网页抓取和真实公开源检索仍是 roadmap；当前版本先完成入口语义和材料卡片显示状态。

文档 / PPT / PDF 线：

- [x] 写 `core workflow` 页面草稿。
- [x] 明确 workflow：Today -> Deep Dive -> Material -> Agent Guidance -> Check-in -> Archive。
- [x] 整理 demo 录屏脚本 v1。
- [x] 写清楚“材料源不等于论文源”。

完成标准：

- [x] iOS 能从 Today 进入 Deep Dive 队列。
- [x] iOS 能看到 Deep Dive 的三种材料入口。
- [x] 录屏路径 v1 明确。

### Day 4（2026-08-09）：iOS Deep Dive 详情页

开发线：

- [x] Deep Dive 详情页先显示材料生成入口，材料生成完成后再显示主文献、候选文献和补充材料。
- [x] 显示当前任务。
- [x] 显示阅读目标。
- [x] 显示选择理由。
- [x] 显示预计用时。
- [x] 删除 `30 / 60 / 90 分钟路径` 区块；当前对收束帮助不大，反而增加噪音。
- [x] 完成标准继续保留，但要做成非可点击、低误导的状态展示；不要用看起来像可点选的圆形控件。
- [ ] 完成标准需要逐步和用户动作联动，例如写笔记后满足 insight 类标准，Check-in 后满足 next action 类标准。
- [x] 上述信息块不做伪点击入口，避免层级混乱。
- [x] `Agent Guidance` 不应再作为和 Check-in 平级的独立入口；应收敛为 Check-in 内部的 `自己编辑 / Agent 生成初稿` 两种模式。
- [x] `我的笔记` 不能只是临时本地输入；至少要在归档时并入 Archive，可回看“标题 / 链接 / 主旨 / 用户笔记 / Check-in 总结”。
- [x] Archive 详情页需要稳定显示原文标题、链接、简介和用户笔记；对旧记录若缺 source metadata，需要通过 session 关联补展示。
- [x] 顶部右上角 `完成/归档` 入口也要带上当前材料上下文，不能只在研究页主按钮路径下才写入原文信息。
- [x] Agent 生成的 Check-in 草稿后续应升级为基于材料 + 用户笔记 + Agent 讨论摘要生成，而不是规则模板填充。
- [x] Deep Dive LLM 下一阶段优先跑通“真材料闭环”：材料确认后，Agent prompt 必须拿到真实材料标题、摘要、URL、PDF metadata、推荐理由，而不是只拿 `mock_paper_primary` / `paper_id` 占位。
- [x] `论文 -> Agent 讨论` 需要绑定当前论文内容：自动注入 paper title、summary、why_selected、selected_passages、sections 和当前阅读问题，让用户无需手动复制材料上下文。
- [x] `Check-in / 归档 -> Agent 生成初稿` 需要基于当前论文、用户笔记、Agent 讨论记录、完成标准生成可归档摘要，而不是泛泛模板。
- [ ] Deep Dive 暂存标题一致性 bug 在真实材料上下文之后立即修复：session 从进行中 / 未完成移动到暂存 / 完成归档时，标题和序号必须保持不变。
- [ ] Deep Dive UI polish 放在数据闭环之后：先确保真实材料、讨论、初稿、归档数据一致，再优化视觉层和交互动效。

文档 / PPT / PDF 线：

- [x] 写 `Agent capability` 页面草稿。
- [x] 解释 Agent 如何基于个人情况、计划、材料偏好生成推荐理由。
- [x] 解释 Agent 如何把材料处理变成下一步行动。
- [x] 准备一张 Agent 能力流程图草稿。

完成标准：

- [x] iOS Deep Dive 详情页可展示。
- [x] Agent 能力叙事成页。

### Day 5（2026-08-10）：iOS Check-in + Agent Guidance

开发线：

- [x] Check-in 放在完成标准下面的按钮中，不裸露在外层。
- [x] Agent Guidance 放在完成标准下面的按钮中。
- [x] Agent Guidance 能生成 Check-in 草稿。
- [x] 用户可修改 Agent 生成的 Summary。
- [x] 用户可修改 Agent 生成的 Key insight。
- [x] 用户可修改 Agent 生成的 Next action。
- [x] 保存后写入归档。

文档 / PPT / PDF 线：

- [x] 写 `closed-loop evidence` 页面草稿。
- [x] 解释 session status 如何变化。
- [x] 解释归档区如何沉淀 check-in。
- [x] 解释下一轮 Agent 如何复用历史和计划上下文。

完成标准：

- [x] 主闭环跑通：Deep Dive -> Agent draft -> Check-in -> Archive。
- [x] closed-loop evidence 页面有初稿。

### Day 6（2026-08-11）：iOS 计划 / 我的

开发线：

- [x] iOS `计划` 页面显示长期目标。
- [x] iOS `计划` 页面显示本周重点。
- [x] iOS `计划` 页面显示当前任务。
- [x] iOS `计划` 页面显示 tracking keywords。
- [x] iOS `我的` 页面显示个人情况 / 简历摘要。
- [x] iOS `我的` 页面新增 `方向配置` 入口，用于替代完整登录前的轻量 Onboarding Profile。
- [x] iOS `方向配置` 改成两阶段：先由用户填写方向类信息，再由 Agent 生成本周计划、检索策略和约束。
- [x] iOS `方向配置` 的提示文案使用 secondary 灰色样式，避免和用户可编辑内容混淆。
- [x] iOS `方向配置` 的方向区拆成四个明确问题，每题单独提供说明和输入空间，避免堆砌四段默认文字。
- [x] iOS `方向配置` 的 `提交方向，让 Agent 生成后续配置` 改成方向区下方独立主按钮。
- [x] iOS `方向配置` 输入框内不再放无信息量 placeholder；问题和说明在输入框外展示。
- [x] iOS `方向配置` 首屏不再把已保存/默认答案预填进四个方向输入框；方向区保留为空白填写空间。
- [x] iOS `方向配置` 保存时空输入不覆盖已有 UserContext，避免用户未展开后续配置时清空计划字段。
- [x] iOS `方向配置` 主按钮文案改为 `提交方向，让 Agent 生成计划`。
- [x] 默认方向配置内容改为贴合当前用户背景：SLAM 几何直觉、4DGS 动态重建、自动驾驶工程经验、World Model / Driving Video Generation 方向判断。
- [x] iOS `方向配置` 支持编辑长期目标、当前方向、当前阶段、背景 / 已有基础。
- [x] iOS `方向配置` 增加目标周期输入，例如 2 周、3 个月、半年、一年。
- [x] Agent 根据目标周期生成 `全周期计划`，并和本周计划一样支持用户编辑。
- [x] iOS `方向配置` 提交后从底部弹出分步确认 sheet：先确认全周期计划，再确认第一周计划，再确认检索策略和约束。
- [x] iOS `方向配置` 每一步都需要用户确认后才进入下一步，最终确认后保存到个人情况 / UserContext。
- [x] iOS `方向配置` 支持在 Agent 生成后编辑本周 focus、下一步动作、领域关键词、关注领域、材料源偏好、时间预算和约束。
- [x] 方向配置保存位置明确：方向 / 背景写入 `UserContext.profile`；周期 / 全周期计划 / 本周计划 / 关键词写入 `UserContext.plan`；材料源偏好 / 时间预算写入 `UserContext.preferences`。
- [x] 后端新增 `PUT /api/user-context`，用于保存单用户本地 UserContext；暂不做登录、多用户和云同步。
- [x] 后端新增 `POST /api/user-context/direction/suggest`，用于根据用户方向生成可编辑的后续配置；OpenRouter 不可用时提供规则 fallback。
- [ ] 计划阶段编辑体验后续增强：支持在阶段详情里新增 / 删除 / 重排目标、执行块和产出，而不是只能编辑已有条目。
- [ ] 计划生成质量后续增强：Agent 需要结合目标周期、每周时间预算、用户背景和材料库生成更贴合的 week/day 任务，减少固定模板扩展。
- [x] iOS `我的` 页面显示领域偏好。
- [x] iOS `我的` 页面显示材料源偏好。
- [x] iOS `我的` 页面显示本地数据说明。

文档 / PPT / PDF 线：

- [x] 写 `data/context` 页面草稿。
- [x] 说明用户上下文包含哪些字段。
- [x] 说明本地记录和隐私边界。
- [x] 说明材料源类型。
- [ ] 将 `source_compliance_note` 整理为提交材料可用版本。

完成标准：

- [x] iOS 能解释“Agent 为什么推荐这份材料”。
- [x] 数据 / 隐私页有初稿。

### Day 7（2026-08-12）：三类轻量 Session + 领域复用表

开发线：

- [x] Today / Manual 中的 `Radar` 入口进入原生轻量工作区，而不是只停留在占位卡片。
- [x] Radar 工作区显示当前计划关键词、近期材料/归档信号、Agent 可扫描的 3 类信号：外部变化、方向变化、下一步机会。
- [x] Radar 支持多种内容注入方式：Agent 自动扫描、输入主题、粘贴 URL、个人上传/PDF 登记、手动材料；生成后直接进入本轮 Radar 结果。
- [x] Radar 生成弹窗的来源选择改为纵向可读列表，避免 5 个选项横向挤压导致文字不可读。
- [x] Radar 支持 `新建 Radar`，先创建空 Radar 卡片；用户点击 `生成本轮 Radar` 后再生成 3 条信号、发生了什么、为什么相关、噪音判断和路由动作。
- [x] Radar 结果以卡片展示，每条卡片可点开查看完整信号判断、来源详情、具体观察、验证问题、噪音判断和路由动作。
- [x] Radar 详情展示原文 / 材料入口：URL 可打开原文，PDF / 手动材料 / Agent 扫描显示当前可追溯来源说明。
- [x] Radar 详情展示关键信息段落提取与 Agent 解析，先基于当前 payload metadata 生成；真实网页/PDF 正文抽取后续接后端。
- [x] Radar 详情页每条信号新增 `Agent 讨论` 入口：进入 AgentChatView 讨论该条目的具体内容；后端按 `signal:<id>` 匹配并把该条目的摘要、技术实质、营销噪音、为何重要、证据状态、关键段落（含摘录 / 分析 / 建议）注入 LLM，配套 `RADAR_DISCUSSION_SYSTEM_PROMPT`；同一条目重复进入复用同一 thread，不同条目各自独立，避免互相覆盖。
- [x] Radar 详情支持 `Radar Check-in`，可把当前信号判断、关键洞察和下一步行动保存到归档。
- [x] Radar 归档入口统一收敛到 `保存到归档`，避免上方 `归档` 按钮和 Check-in 归档语义重复。
- [x] Radar 生成结果写回 session payload，重新进入同一个 Radar 卡片时直接恢复已生成结果，不再依赖前端临时状态。
- [x] Radar 页面显示 `Agent 能做什么`：根据计划和归档发现值得追踪的新信号，帮助用户决定是否进入 Deep Dive。
- [x] Radar 结果先只支持查看、转 Deep Dive / 暂存决策，不做完整信号 CRUD。
- [x] Radar 真实外部检索闭环 v0：已接入公开网页 / 新闻 RSS 作为默认行业动态源，生成 3 条公开网页信号；arXiv / GitHub 不再作为默认 Radar 主来源。
- [x] Radar 定向逻辑 v0：后端读取 UserContext 中的 `goal`、`current_stage`、`weekly_focus`、`active_tasks`、`tracking_keywords` 和 `preferences.fields`，动态生成 query 和相关性过滤，不写死具体领域方向。
- [x] Radar 无 mock fallback：公开源检索失败或过滤后为空时返回空结果和失败说明，不再把样例 mock 材料伪装成真实推送。
- [x] Radar 跨 session 去重 v0：生成 Radar 时排除历史已推送 URL，避免连续新建多个 Radar 时优先生成同一批材料。
- [ ] Radar 接入更多真实公开源：继续补官方博客 / release notes、指定 URL、公众号公开网页、机构官网；arXiv / GitHub 后续作为技术证据补充源，而不是默认主推送源。
- [x] Radar 原文抓取与摘录 v0：优先抓取推送网页正文并提取 3-5 条有信息量的原文段落，卡片标题用段落主旨短句，严格区分来源摘录 `excerpt` 与 Agent 解析 `analysis`，并为每条 passage 生成针对性 `suggestion`。
- [x] Radar 正文抓取改为可选 + 证据状态标记：radar 生成默认不再同步抓原文（避免 Google News 跳转页抓取失败拖慢并产出无意义占位），item 用 `evidence_status` 区分 `excerpt_available` / `metadata_with_structured_summary` / `metadata_only`；读原文全文留待 Deep Dive。
- [ ] Radar 原文正文抓取增强：后续接更稳定的公开源 / 官方文档 / GitHub release / 论文摘要，补充更细的段落位置、正文摘录和引用定位；真实正文阅读能力应下沉到 Deep Dive 阶段，而不是 radar skim 阶段。
- [ ] Radar 去重和噪音过滤增强：过滤重复新闻、纯营销稿、股票 / 销量消息、偏题泛科技内容和无实质产品 / 成果 / 机构动作的内容，只保留与用户当前目标有关的行业信号。
- [ ] Radar 跨 session 去重增强：生成新 Radar 时继续补齐 source id、标题相似度、已归档、已忽略、已转 Deep Dive 的排除逻辑。
- [ ] Radar 增量检索：按 published / updated 时间过滤新论文、新 repo release 和官方更新，支持每天固定节奏只推新增信号。
- [ ] Radar query 轮换增强：根据用户方向配置、当前周计划、近期归档和噪音反馈自动调整检索词，并支持多轮扩展同义词 / 机构名 / 平台名。
- [ ] Radar 重复主题聚合：当多条来源指向同一技术主题时合并为一条主题信号，保留多个依据链接和 Agent 综合判断。
- [ ] Radar 排序和路由：按与本周计划关系、证据强度、可行动性和噪音程度排序，并输出 `转 Deep Dive / 暂存 / 忽略` 的理由。
- [ ] Radar 状态列表展示：在 Radar 工作区或归档页能查看 `track_later`、`noise`、`deep_dive`、`archived` 的单条 Radar item，而不是只能在详情页看到状态。
- [ ] Radar 定时 / 手动刷新策略：明确当前竞赛版是点击生成，后续版本再接固定节奏自动拉取和推送。
- [x] Today / Manual 中的 `Weekly Studio` 入口进入原生轻量工作区。
- [x] Weekly Studio 工作区显示本周重点、当前任务、已完成/未完成归档摘要和下周候选动作。
- [x] Weekly Studio 支持 `新建 Weekly Studio`，生成一份轻量周复盘草稿：本周完成、卡点、下周 3 个优先任务。
- [x] Weekly Studio 页面显示 `Agent 能做什么`：把归档记录、计划和未完成项整理成可执行的下一周安排。
- [x] Weekly Studio 结果先只支持编辑草稿和保存到计划上下文，不做完整周报系统。
- [ ] Today / Manual 中的 `Opportunity Alignment` 入口进入原生轻量工作区。
- [ ] Opportunity Alignment 工作区显示当前方向、目标版本、能力证据和机会/岗位/项目匹配维度。
- [ ] Opportunity Alignment 支持 `新建 Alignment`，生成一份轻量匹配草稿：机会描述、匹配点、缺口、下一步动作。
- [ ] Opportunity Alignment 页面显示 `Agent 能做什么`：把个人背景、计划产出和外部机会对齐，指出需要补的证据。
- [ ] Opportunity Alignment 结果先只支持查看、编辑和转成当前任务，不做完整 JD / opportunity CRUD。
- [ ] 三类轻量 session 都要显示来源说明：它们引用了哪些用户上下文字段、计划字段或归档摘要。（Radar 已完成）
- [ ] 三类轻量 session 都要有空状态、新建中状态、生成失败状态和返回 Today 的路径。
- [ ] 三类轻量 session 的样式保持一致：顶部说明、当前工作区、Agent 能做什么、新建按钮、结果卡片。
- [ ] 不做完整 CRUD；Day 7 只完成可录屏、可解释、可从主链路进入的轻量版本。

文档 / PPT / PDF 线：

- [x] 写 `domain mapping table` 独立页。
- [x] 为 Radar 写 demo 叙事：用户不用主动搜资讯，Agent 基于计划和归档提示“今天值得看什么信号”。
- [x] 为 Weekly Studio 写 demo 叙事：用户不用从零复盘，Agent 把本周记录转成下周行动。
- [x] 为 Opportunity Alignment 写 demo 叙事：用户不用手动对齐机会，Agent 把目标、能力证据和机会缺口连起来。
- [x] 在 `domain mapping table` 中映射职业能力建设：Deep Dive=能力证据，Radar=行业信号，Weekly Studio=节奏管理，Opportunity Alignment=岗位/机会匹配。
- [x] 在 `domain mapping table` 中映射研究方向探索：Deep Dive=论文/技术路线，Radar=新论文/新项目，Weekly Studio=研究节奏，Opportunity Alignment=课题/合作机会。
- [x] 在 `domain mapping table` 中映射创作者 / 视觉 IP 运营：Deep Dive=案例拆解，Radar=趋势/平台信号，Weekly Studio=内容节奏，Opportunity Alignment=商业合作/选题匹配。
- [x] 在 `domain mapping table` 中映射创业 / 产品探索：Deep Dive=用户/竞品研究，Radar=市场信号，Weekly Studio=实验复盘，Opportunity Alignment=机会优先级。
- [x] 在 `domain mapping table` 中映射语言学习：Deep Dive=材料精读，Radar=输入源发现，Weekly Studio=学习复盘，Opportunity Alignment=考试/工作/表达场景匹配。
- [ ] 准备一页 `three lightweight sessions` 截图占位：三个卡片分别说明输入、Agent 处理、输出。
- [x] 更新 demo 录屏脚本：Deep Dive 作为主链路，Radar / Weekly Studio / Opportunity Alignment 作为轻量扩展镜头。

完成标准：

- [ ] 四类 session 在 iOS 可见，且都能从 Today / Manual 进入。
- [x] Radar 可生成或展示一份轻量信号扫描结果。
- [x] Weekly Studio 可生成或展示一份轻量周复盘草稿。
- [ ] Opportunity Alignment 可生成或展示一份轻量机会匹配草稿。
- [ ] 三类轻量 session 都能解释 `Agent 能做什么` 和引用了哪些上下文。
- [x] 领域复用映射表完成，并能放入 proposal draft。

### Day 8（2026-08-13）：调试冻结 + Proposal Draft

开发线：

- [ ] 解决 iPhone / Appetize / 模拟器调试链路。
- [ ] 修复 iOS 编译阻塞。
- [ ] 修复接口状态错误。
- [ ] 修复主要布局问题。
- [ ] 冻结主 demo path。
- [ ] 录一轮内部调试视频。

文档 / PPT / PDF 线：

- [x] 合并 proposal draft。
- [x] 加入封面。
- [x] 加入问题、用户、workflow。
- [x] 加入 Agent 架构。
- [x] 加入 domain mapping。
- [x] 加入当前进度、限制和 roadmap。

完成标准：

- [ ] iOS 可录屏候选版本形成。
- [x] PPT/PDF draft v1 完成。

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

- [x] iOS 原生 Today 能连接 GOAI/FastAPI 后端。
- [x] iOS 原生 Deep Dive 队列页。
- [x] iOS 原生 Deep Dive 材料生成入口：Agent 检索 / URL / 个人上传。
- [x] iOS 原生 Deep Dive 详情页：材料生成后显示主文献、候选文献、推荐理由和阅读入口。
- [x] iOS 原生 Agent Guidance：生成 Check-in 草稿。
- [x] iOS 原生 Check-in：用户可修改并写入归档。
- [x] iOS 原生归档区显示完成 / 跳过 / 未完成归档记录。
- [x] iOS 原生计划/我的展示用户上下文。

轻量做：

- [ ] Radar 当前工作区 + 新建入口。
- [x] Weekly Studio 当前工作区 + 新建入口。
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

当前 canonical proposal deck：

```text
ppt/orbit_engine_value_proposal.pptx
submission/orbit_engine_value_proposal.pptx
```

当前 deck 覆盖情况：

1. [x] 封面：圆周引擎 / Orbit Engine。
2. [x] Track Fit：为什么适合 Boundless Agents。
3. [x] 问题：不是缺计划，而是每天启动学习 / 探索的摩擦太高。
4. [x] 用户：有长期目标、需要周期性行动和反馈的人。
5. [x] 产品定义：周期性 Agent session，而不是 todo app。
6. [x] 四类 session：Signal Radar / Deep Dive / Opportunity Alignment / Weekly Studio。
7. [x] Demo Loop：Today -> Queue -> Material -> Guidance -> Check-in -> History。
8. [x] Product Evidence：移动端产品形态和当前截图证据。
9. [x] 系统架构：SwiftUI / mobile Web demo + FastAPI + SQLite + BaseSession + MaterialSource。
10. [x] 数据与安全：本地 UserContext、材料 metadata、公开 / 用户登记材料、human-in-the-loop。
11. [x] 领域复用映射表：职业能力、研究探索、创作者/IP、产品创业、语言学习。
12. [x] 当前进度与 roadmap：已完成、进行中、下一步。
13. [x] Scoring Alignment：行业场景价值 / Agent 能力与闭环 / 产品体验 / 技术可行性 / 合规边界 / 开源复用。
14. [x] Demo Walkthrough：60-90 秒视频每一步怎么点、证明什么。
15. [x] Why Orbit Engine Wins：对比 Todo、Notion、Readwise、普通论文助手、打卡工具、职业规划工具。
16. [x] Value Summary：一句话价值收束。

仍需随最终录屏更新：

- [ ] Product Evidence 页替换为最终 iOS 录屏截图，而不是 mobile Web / iOS-style 占位截图。
- [ ] Progress & Roadmap 页根据 8/15 最终代码状态更新措辞。
- [ ] Demo Walkthrough 页根据最终录屏路径微调按钮名称和步骤名。

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
-> 写入 Archive
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
- [x] 明确目标底部栏：`今日 / 归档 / 计划 / 我的`。
- [x] 明确 Day 2 优先验证 endpoint：`/api/health`、`/api/sessions/today`、`/api/user-context`。
- [x] 根据用户评审要求扩展 Day 2 开发项：Scheduled / Manual、四类 session 入口、底部四栏、移除独立 JD 栏、后端默认 URL 更新但保留覆盖能力。
- [x] 完成 Day2 iOS 代码线：默认后端 URL 更新为 `https://continuous-ranges-contacted-licence.trycloudflare.com`，仍保留 `UserDefaults` / 设置页覆盖。
- [x] iOS 底部栏改为 `今日 / 归档 / 计划 / 我的`；`JD` 不再作为底部栏，`设置` 并入 `我的`。
- [x] iOS Today 增加 Scheduled / Manual segmented control。
- [x] Manual 增加四个入口：Radar、Deep Dive、Weekly Studio、Opportunity Alignment。
- [x] Manual 入口暂时复用现有后端日期映射：Radar=`2026-08-04`、Opportunity Alignment=`2026-08-05`、Deep Dive=`2026-08-06`、Weekly Studio=`2026-08-09`。
- [x] TodayViewModel 接入 `/api/health`、`/api/sessions/today`、`/api/user-context`。
- [x] 后端 smoke 通过：`/api/health`、`/api/user-context`、`/api/sessions/today`、四个 manual mock date 均返回 200。
- [!] 本机无 `xcodebuild`，iOS 编译和 Appetize/真机视觉验证待 Codemagic 完成。
- [x] iOS Today session 卡片不再直接进入 workspace，改为先进入 session type 队列 / 管理页。
- [x] 新增 `SessionQueueView`：展示进行中 / 未完成 session，已完成 / 跳过 / 未完成归档记录进入归档区。
- [x] `SessionQueueView` 增加新建同类 session 按钮，当前版本通过 `POST /api/sessions/mock?date=...` 生成并保存示例 session。
- [x] 队列层覆盖 Radar、Deep Dive、Weekly Studio、Opportunity Alignment；其中 Deep Dive 对应 Day3 队列页的前半部分。
- [x] Deep Dive 工作区新增 `材料生成` 入口：Agent 检索、URL、个人上传统一进入同一材料生成 sheet。
- [x] Agent 检索默认 `Agent 自动生成`，也支持 `输入检索主题`。
- [!] 真实 PDF 上传、URL 正文抓取和公开源检索尚未实现；当前先保存材料 metadata / 检索需求。
- [x] 未完成队列中的 session 行增加 `第 N 个 · 日期` 标识，解决多个同类型未完成项难以区分的问题。
- [x] 具体 workspace 增加右上角 `完成/归档` 入口。
- [x] `完成/归档` 表单支持填写用时、简单总结、关键收获和下一步。
- [x] 保存归档调用 `POST /api/sessions/{session_id}/completion/confirm`，写入归档区，并让 completed session 从未完成队列中过滤掉。
- [x] 后端 completion smoke 通过：生成 Deep Dive session 后归档，session/check-in 均返回 `completed`。
- [!] Agent 对话当前仍是 mock：后端 `ChatService` 直接使用 `MockLLMService()`，尚未按 `llm_provider` 切换真实 LLM。

### 2026-08-07

- [x] Deep Dive 研究页新增材料生成状态门槛：进入工作区后先只显示 `材料生成`，生成完成后才显示主文献、候选文献和补充材料。
- [x] `材料生成` sheet 默认进入 Agent 检索，并支持 `Agent 自动生成` / `输入检索主题` 两种模式。
- [x] URL、Agent 检索需求和个人上传入口统一进入材料生成 sheet；当前保存到 `/api/user-context/materials`。
- [x] 归档入口调整为材料生成后才显示，并统一为和 `材料生成` 一致的标准 List `Label` 样式。
- [x] 论文详情页调整阅读流程：先进入 PDF 阅读器 / Agent 讨论，再点击 `Agent 自动读取并提取关键段落`，点击后才显示阅读章节、精选段落和关键图。
- [x] `我的笔记` 从内联输入改成入口卡片 `写入笔记`，弹出 sheet 后支持 `自己编辑` 和 `Agent 生成初稿` 两种方式。
- [x] 修复 Codemagic / Xcode build 中两类 SwiftUI `Section + footer` initializer 编译错误。
- [x] 后端默认 tunnel 多次随测试更新，当前默认 URL 为 `https://continuous-ranges-contacted-licence.trycloudflare.com`，仍保留 `UserDefaults` 覆盖和旧默认 URL 迁移。
- [!] 本机仍无 `xcodebuild`，iOS 编译验证依赖 Web/Codemagic build log。
- [x] Deep Dive 材料生成后新增 `完成标准` 区块，优先读取 session completion criteria；为空时使用 Deep Dive 默认完成标准。
- [x] Deep Dive 材料生成后新增 `30 / 60 / 90 分钟路径`，用于展示不同时间预算下的阅读收束方式。
- [x] Deep Dive 完成标准下新增 `Agent Guidance` 与 `Check-in / 归档` 两个主路径按钮。
- [x] `完成/归档` sheet 新增 `自己编辑 / Agent 生成初稿`，Agent 草稿会填充 Summary、Key insight 和 Next action，用户仍可修改后保存。

### 2026-08-08

- [!] Deep Dive 暂存标题一致性仍未验收通过：用户反馈进行中 / 未完成卡片暂存后，在归档页 `暂存` 区仍显示为 `Deep Dive-日期-1`，与原卡片序号不一致。下一轮需先重走真实 iOS 流程或加端到端可观测日志，确认后端 session title、checkin summary、iOS HistoryView 展示源三者完全一致。
- [x] LLM 接入成功后确认 Deep Dive 下一阶段优先级：先做真实材料上下文注入，再做论文 Agent 讨论绑定当前论文内容，再做基于材料 / 笔记 / 讨论 / 完成标准的 Check-in 初稿，随后修复暂存标题一致性，最后做 UI polish。
- [x] Deep Dive Agent 讨论已注入真实材料上下文：后端会根据 session payload 和 context_refs 解析 confirmed materials、paper、reader sections、selected passages、key figures、notes，再发给 LLM。

### 2026-08-09

- [x] 默认后端 URL 更新为 `https://continuous-ranges-contacted-licence.trycloudflare.com`，并通过 `/api/health` 验证 OpenRouter 配置正常。
- [x] `Check-in / 归档 -> Agent 生成初稿` 已升级为 LLM 上下文草稿：后端 draft payload 注入 selected materials、primary paper、paper reader、用户笔记、完成标准和最近 Agent 讨论记录。
- [x] 确认 Day 6 `计划 / 我的` 应先做轻量方向配置，而不是完整登录；`我的 -> 方向配置` 将作为 Deep Dive Agent 自动选材的用户方向输入。
- [x] `我的 -> 方向配置` 调整为用户先填“方向”，提交后由 Agent 生成“本周计划 / Agent 检索策略 / 约束”，并支持用户继续修改保存。
- [x] `我的 -> 方向配置` 方向区 UI 调整为四个清晰问题 + 独立提交按钮；灰色说明与用户输入区分展示。
- [x] `我的 -> 方向配置` 输入框 placeholder 清空，默认四题内容改为当前用户 4DGS / WM 背景，按钮文案调整为对称表达。
- [x] `我的 -> 方向配置` 方向输入框保持空白，按钮改为纯文本居中，修复图标导致的视觉不对齐。
- [x] `我的 -> 方向配置` 增加目标周期和全周期计划；Agent 生成内容均保持可编辑，保存后进入个人上下文 UserContext。
- [x] `我的 -> 方向配置` 改为底部弹出分步确认：全周期计划 -> 第一周计划 -> 检索策略 / 约束 -> 保存到个人情况。

### 2026-08-12

- [x] Review 当前手工 PPT：`ppt/圆周引擎OrbitEngine.pptx`。
- [x] 当前 PPT 已从 8 页扩展到 9 页，已覆盖封面、Boundless Agents 适配、问题、目标用户、四类 session、六步闭环和领域复用映射表。
- [x] 当前 PPT 的主叙事进度可用：已经能说明“不是缺计划，而是启动成本 / 筛选成本 / 沉淀断层”，也能说明四类 session 如何服务周期性能力建设。
- [!] 当前 PPT 第 8-9 页 `Agent Ability` 仍是明显占位：只抽取到标题，缺少 Task Input / Intent / Planning / MaterialSource / Guidance / Check-in / History 的完整映射。
- [x] Reference proposal deck `ppt/orbit_engine_value_proposal.pptx` 已覆盖初赛关键价值页：`Scoring Alignment`、`Demo Walkthrough`、`Why Orbit Engine Wins`。
- [x] Reference proposal deck 已覆盖提交关键页：技术架构、数据与安全边界、当前进度 / 限制 / roadmap、移动端产品证据截图。
- [x] 已据此更新文档线 checklist：以 `orbit_engine_value_proposal.pptx` 作为 canonical proposal deck，已覆盖项标记完成；只保留最终录屏后需要更新的截图、进度措辞和按钮名。
- [x] 补充 `Why Orbit Engine Wins` 页：增加“打卡工具”对比，明确 Check-in 只是验证节点，不是产品边界。
- [x] Radar 新建行为修正：新建 Radar 只创建空卡片，点击 `生成本轮 Radar` 后才触发后端公开源检索并写回 session payload。
- [x] Radar 真实行业动态源修正：默认推送改为公开网页 / 新闻 RSS 的行业动态，不再把论文 / GitHub 作为默认主来源。
- [x] Radar 定向逻辑修正：检索 query 和相关性过滤改为读取用户方向配置、当前计划、active tasks、tracking keywords 和偏好领域，不再写死自动驾驶 / 机器人 / 世界模型等方向。
- [x] Radar 空结果问题修正：中文长目标会拆成更短的可检索关键词，中文 query 使用中文行业动态后缀，避免中英混拼导致 Google News RSS 返回 0 条。
- [x] Radar mock 问题修正：公开源失败时返回空结果和说明，不再 fallback 到 mock；旧 session 中的 `mock_` item 在 iOS 侧过滤不展示。
- [x] Radar smoke 通过：临时数据库中非 Radar 日期显式新建 `tech_radar` session 初始 0 条，点击生成后返回 3 条公开网页行业动态。
- [x] Radar 关键信息摘录修正：`source_passages` 改为标题信号、摘要摘录、来源与时间、当前目标匹配依据、来源标签 / 类型线索；`excerpt` 只放来源可追溯信息，`analysis` 才放 Agent 解析，避免把 Agent 判断伪装成原文摘录。
- [x] Radar 关键信息摘录二次修正：`source_passages` 改为优先读取推送链接网页正文，抽取 3-5 条有信息量的原文段落；每条卡片只承载 `excerpt` 原文摘录和 `analysis` Agent 对该段的解析。网页正文无法抓取时才退回 RSS 摘要 / 标题 / 来源线索，并在解析中明确标记为兜底。
- [x] 修复 Radar「生成本轮 Radar」无反应问题：根因是 8000 端口后端进程为 8/10 启动的旧代码，缺少 8/12 commit `74ceb90` 加入的 `POST /api/sessions/{session_id}/radar/refresh` 路由，返回 404。已重启 8000 后端加载最新代码，并在 8000 / cloudflared tunnel 上验证该端点返回 200 且生成 3 条行业信号。
- [x] 更新 iOS 默认后端 URL 为当前可用 tunnel：`https://refused-atom-org-soil.trycloudflare.com`（旧默认 `builder-estimates-leads-beneath` 已死，`continuous-ranges-contacted-licence` 返回 530 origin 不可达）。旧 URL 全部加入 legacy 迁移列表，`UserDefaults` 覆盖逻辑仍保留。
- [x] Radar 详情页「关键信息摘录」改造：卡片改为展示 Agent 从推送原文提取的关键段落（3-5 个），卡片标题用段落主旨短句；点开卡片显示三部分：`Agent 提取的原文`（excerpt + 打开来源链接）、`Agent 解析`（analysis）、`对用户的建议`（suggestion）。
- [x] 后端 `RadarSourcePassage` 新增 `suggestion` 字段；`_source_passages` 重写：原文正文抓取成功时生成主旨标题 + excerpt + analysis + suggestion（suggestion 结合当前方向关键词和段落类型生成针对性建议）；抓取失败时不再 fallback 到 RSS 摘要 / 标题 / 来源线索，改为单条「原文正文抓取失败」说明并提示打开原文链接。
- [x] iOS `TechRadar.swift` 的 `RadarSourcePassage` 增加 `suggestion`；`TechRadarView.swift` 的 `keyPassages` / `RadarPassageCardView` / `RadarPassageDetailView` 同步更新；旧 session 无 source_passages 时给出失败说明而非拼装占位卡片。
- [!] Google News RSS 跳转链接（news.google.com/rss/articles/...）正文抓取不稳定，当前实际生成结果多为「原文正文抓取失败」；真实段落展示需要更稳定的公开源或网页正文抓取增强，已列入 roadmap。

### 2026-08-13

- [x] Radar 正文抓取改为可选（commit `263f007`）：radar 生成默认不再同步抓原文，`_should_fetch_source_passages` 仅在 `extra.fetch_passages is True` 时触发；`_source_passages` 抓取失败返回 `[]`，不再塞固定「原文正文抓取失败」占位。
- [x] `RadarItem` 新增 `evidence_status`：`excerpt_available`（抓到段落）/ `metadata_with_structured_summary`（arXiv / GitHub 带摘要）/ `metadata_only`（仅标题摘要）；iOS `TechRadar.swift` 同步 `evidenceStatus`，默认 `metadata_only`。
- [x] Radar 详情页每条信号新增 `Agent 讨论` 入口（commit `ba228ec`）：`RadarDecisionDetailView` 增加 `Agent 讨论` Section，进入 `AgentChatView` 并携带 `context_refs=["tech_radar", "signal:<id>"]`。
- [x] 后端 `ChatService` 支持 radar 讨论上下文注入：`_radar_context_message` 按 `signal:<id>` 匹配条目并序列化 title / summary / technical_substance / marketing_noise / why_it_matters / evidence_status / recommended_depth / source_passages 注入 LLM；未命中时回退用前 3 条；新增 `RADAR_DISCUSSION_SYSTEM_PROMPT`。
- [x] 修复 `ChatService.create_thread` 互相覆盖问题：同 session 相同 context_refs 复用已有 thread（幂等），不同 context_refs 各自新建独立 thread；之前复用同一个 `session.ai_chat_thread_id` + `INSERT OR REPLACE` 会清空前一条讨论。
- [x] 新增后端测试 2 个：`test_radar_chat_messages_include_real_signal_context`（验证讨论消息带真实条目 + 段落上下文）、`test_radar_per_item_threads_do_not_clobber_each_other`（验证多条目讨论独立、同条目复用）；`test_chat_api.py` 6/6 通过，全量 49 通过。
- [x] 修复 3 个既有失败测试（commit `3a0f037`）：`test_technical_radar_agent_uses_search_results` 的 fake 方法名对齐 `search_industry_sources`、summary 断言改 `公开网页`；删除 `test_mock_product_radar_session_has_items` 过时的 `visuals >= 1` 断言；给 mock JD seed 补真实技术 JD 文本使 `role_type` 产出 `research_engineer`。
- [x] 默认后端 URL 更新为 `https://limits-celebrate-ide-termination.trycloudflare.com`，旧默认加入 legacy 迁移列表，`UserDefaults` 覆盖逻辑保留。
- [x] Opportunity Alignment 用户可见命名收口（commit `fc90bfb`，已推送）：主页面标题与 navigation title 统一为 `Opportunity Alignment`；`添加 JD` / `保存 JD` 改为“添加机会” / “保存机会”；`JD 库` 改为“机会库”；概览数量指标改为“机会”。仅修改 SwiftUI 展示文案，保留 `JDIntelligenceView`、`JDEntry` 等内部类型和数据结构，避免无必要的迁移风险。
- [x] Weekly Studio 轻量复盘闭环：周日 review session 在 iOS 路由中从 `ResearchReaderView` 分流到 `WeeklyStudioView`，不再显示“材料生成”；页面读取当前周 `UserContext.plan` 与周一至周日的 Check-in，展示完成/未完成摘要。后端仍复用 `research_feeder` 内部类型，但为 `manual_deep_dive` review 下发专用完成标准；`test_coordinator.py` 2/2 通过。
- [x] Weekly Studio 复盘语义收紧：本周计划进度不再把 Weekly Studio 自身当作待完成工作；“本周完成 / 卡点”改由后端 Weekly Studio Agent 基于本周 Check-in 与原计划生成（LLM 不可用时走明确规则 fallback）；下周只给原计划内的优先顺序建议，保存默认仅同步首项 `next_action`，不重写 `weekly_focus` 或 `active_tasks`。
- [x] iOS 默认后端 URL 更新为 `https://basis-assignment-capable-soc.trycloudflare.com`；前一 tunnel 加入 legacy 列表，使旧 `UserDefaults` 覆盖自动迁移到新默认地址。
- [!] 仍有两项与 radar 无关的既有失败测试未处理：`test_material_resume_archive.py`（`str.removeprefix` 需 Python 3.9+，当前 venv 为 3.8）、`test_persistence.py::test_direction_profile_suggestion_uses_edited_full_cycle_plan`。
