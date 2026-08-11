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
- [x] 确认 iOS 底部栏目标：`今日 / 归档 / 计划 / 我的`。
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

- [x] iOS APIClient 指向 GOAI FastAPI backend。
- [x] 默认后端 URL 改为 `https://comparable-electron-filename-period.trycloudflare.com`。
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

- [ ] 写 `problem` 页面草稿：不是缺计划，而是启动成本高。
- [ ] 写 `user` 页面草稿：有长期目标、需要周期性行动和反馈的人。
- [ ] 写 `scenario` 页面草稿：早晨/碎片时间打开 app，直接进入今日 session。
- [ ] 收集 iOS Today 截图占位或草图。

完成标准：

- [x] iOS Today 能读后端。
- [x] iOS 首页具备 Scheduled / Manual 两种入口。
- [x] iOS Manual 能看到四类 session 入口。
- [x] iOS 底部栏变为 `今日 / 归档 / 计划 / 我的`。
- [x] 后端默认 URL 已更新，同时仍可被用户配置覆盖。
- [ ] PPT 前 3 页有文字初稿。

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

- [ ] 写 `core workflow` 页面草稿。
- [ ] 明确 workflow：Today -> Deep Dive -> Material -> Agent Guidance -> Check-in -> Archive。
- [ ] 整理 demo 录屏脚本 v1。
- [ ] 写清楚“材料源不等于论文源”。

完成标准：

- [x] iOS 能从 Today 进入 Deep Dive 队列。
- [x] iOS 能看到 Deep Dive 的三种材料入口。
- [ ] 录屏路径 v1 明确。

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

- [ ] 写 `Agent capability` 页面草稿。
- [ ] 解释 Agent 如何基于个人情况、计划、材料偏好生成推荐理由。
- [ ] 解释 Agent 如何把材料处理变成下一步行动。
- [ ] 准备一张 Agent 能力流程图草稿。

完成标准：

- [x] iOS Deep Dive 详情页可展示。
- [ ] Agent 能力叙事成页。

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

- [ ] 写 `closed-loop evidence` 页面草稿。
- [ ] 解释 session status 如何变化。
- [ ] 解释归档区如何沉淀 check-in。
- [ ] 解释下一轮 Agent 如何复用历史和计划上下文。

完成标准：

- [x] 主闭环跑通：Deep Dive -> Agent draft -> Check-in -> Archive。
- [ ] closed-loop evidence 页面有初稿。

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

- [x] Today / Manual 中的 `Radar` 入口进入原生轻量工作区，而不是只停留在占位卡片。
- [x] Radar 工作区显示当前计划关键词、近期材料/归档信号、Agent 可扫描的 3 类信号：外部变化、方向变化、下一步机会。
- [x] Radar 支持多种内容注入方式：Agent 自动扫描、输入主题、粘贴 URL、个人上传/PDF 登记、手动材料；生成后直接进入本轮 Radar 结果。
- [x] Radar 生成弹窗的来源选择改为纵向可读列表，避免 5 个选项横向挤压导致文字不可读。
- [x] Radar 支持 `新建 Radar`，直接生成本轮扫描结果：3-5 条信号、发生了什么、为什么相关、噪音判断和路由动作。
- [x] Radar 结果以卡片展示，每条卡片可点开查看完整信号判断、来源详情、具体观察、验证问题、噪音判断和路由动作。
- [x] Radar 详情展示原文 / 材料入口：URL 可打开原文，PDF / 手动材料 / Agent 扫描显示当前可追溯来源说明。
- [x] Radar 详情展示关键信息段落提取与 Agent 解析，先基于当前 payload metadata 生成；真实网页/PDF 正文抽取后续接后端。
- [x] Radar 详情支持 `Radar Check-in`，可把当前信号判断、关键洞察和下一步行动保存到归档。
- [x] Radar 的 `归档` 和 `保存到归档` 需要真实写入归档页：归档按钮写入 archived 暂存卡片，Check-in 写入 completed 归档记录。
- [x] Radar 页面显示 `Agent 能做什么`：根据计划和归档发现值得追踪的新信号，帮助用户决定是否进入 Deep Dive。
- [x] Radar 结果先只支持查看、转 Deep Dive / 暂存决策，不做完整信号 CRUD。
- [ ] Today / Manual 中的 `Weekly Studio` 入口进入原生轻量工作区。
- [ ] Weekly Studio 工作区显示本周重点、当前任务、已完成/未完成归档摘要和下周候选动作。
- [ ] Weekly Studio 支持 `新建 Weekly Studio`，生成一份轻量周复盘草稿：本周完成、卡点、下周 3 个优先任务。
- [ ] Weekly Studio 页面显示 `Agent 能做什么`：把归档记录、计划和未完成项整理成可执行的下一周安排。
- [ ] Weekly Studio 结果先只支持编辑草稿和保存到计划上下文，不做完整周报系统。
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

- [ ] 写 `domain mapping table` 独立页。
- [ ] 为 Radar 写 demo 叙事：用户不用主动搜资讯，Agent 基于计划和归档提示“今天值得看什么信号”。
- [ ] 为 Weekly Studio 写 demo 叙事：用户不用从零复盘，Agent 把本周记录转成下周行动。
- [ ] 为 Opportunity Alignment 写 demo 叙事：用户不用手动对齐机会，Agent 把目标、能力证据和机会缺口连起来。
- [ ] 在 `domain mapping table` 中映射职业能力建设：Deep Dive=能力证据，Radar=行业信号，Weekly Studio=节奏管理，Opportunity Alignment=岗位/机会匹配。
- [ ] 在 `domain mapping table` 中映射研究方向探索：Deep Dive=论文/技术路线，Radar=新论文/新项目，Weekly Studio=研究节奏，Opportunity Alignment=课题/合作机会。
- [ ] 在 `domain mapping table` 中映射创作者 / 视觉 IP 运营：Deep Dive=案例拆解，Radar=趋势/平台信号，Weekly Studio=内容节奏，Opportunity Alignment=商业合作/选题匹配。
- [ ] 在 `domain mapping table` 中映射创业 / 产品探索：Deep Dive=用户/竞品研究，Radar=市场信号，Weekly Studio=实验复盘，Opportunity Alignment=机会优先级。
- [ ] 在 `domain mapping table` 中映射语言学习：Deep Dive=材料精读，Radar=输入源发现，Weekly Studio=学习复盘，Opportunity Alignment=考试/工作/表达场景匹配。
- [ ] 准备一页 `three lightweight sessions` 截图占位：三个卡片分别说明输入、Agent 处理、输出。
- [ ] 更新 demo 录屏脚本：Deep Dive 作为主链路，Radar / Weekly Studio / Opportunity Alignment 作为轻量扩展镜头。

完成标准：

- [ ] 四类 session 在 iOS 可见，且都能从 Today / Manual 进入。
- [x] Radar 可生成或展示一份轻量信号扫描结果。
- [ ] Weekly Studio 可生成或展示一份轻量周复盘草稿。
- [ ] Opportunity Alignment 可生成或展示一份轻量机会匹配草稿。
- [ ] 三类轻量 session 都能解释 `Agent 能做什么` 和引用了哪些上下文。
- [ ] 领域复用映射表完成，并能放入 proposal draft。

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
5. 核心 workflow：Today -> Deep Dive -> Agent Guidance -> Check-in -> Archive。
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
- [x] 完成 Day2 iOS 代码线：默认后端 URL 更新为 `https://comparable-electron-filename-period.trycloudflare.com`，仍保留 `UserDefaults` / 设置页覆盖。
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
- [x] 后端默认 tunnel 多次随测试更新，当前默认 URL 为 `https://comparable-electron-filename-period.trycloudflare.com`，仍保留 `UserDefaults` 覆盖和旧默认 URL 迁移。
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

- [x] 默认后端 URL 更新为 `https://comparable-electron-filename-period.trycloudflare.com`，并通过 `/api/health` 验证 OpenRouter 配置正常。
- [x] `Check-in / 归档 -> Agent 生成初稿` 已升级为 LLM 上下文草稿：后端 draft payload 注入 selected materials、primary paper、paper reader、用户笔记、完成标准和最近 Agent 讨论记录。
- [x] 确认 Day 6 `计划 / 我的` 应先做轻量方向配置，而不是完整登录；`我的 -> 方向配置` 将作为 Deep Dive Agent 自动选材的用户方向输入。
- [x] `我的 -> 方向配置` 调整为用户先填“方向”，提交后由 Agent 生成“本周计划 / Agent 检索策略 / 约束”，并支持用户继续修改保存。
- [x] `我的 -> 方向配置` 方向区 UI 调整为四个清晰问题 + 独立提交按钮；灰色说明与用户输入区分展示。
- [x] `我的 -> 方向配置` 输入框 placeholder 清空，默认四题内容改为当前用户 4DGS / WM 背景，按钮文案调整为对称表达。
- [x] `我的 -> 方向配置` 方向输入框保持空白，按钮改为纯文本居中，修复图标导致的视觉不对齐。
- [x] `我的 -> 方向配置` 增加目标周期和全周期计划；Agent 生成内容均保持可编辑，保存后进入个人上下文 UserContext。
- [x] `我的 -> 方向配置` 改为底部弹出分步确认：全周期计划 -> 第一周计划 -> 检索策略 / 约束 -> 保存到个人情况。
