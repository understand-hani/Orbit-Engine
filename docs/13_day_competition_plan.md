# 13 天竞赛计划

最后更新：2026-08-05

截止日期：2026-08-16

项目名称：

```text
圆周引擎 / Orbit Engine
```

参赛赛道：

```text
GOAI 无界应用 / Boundless Agents
AI + Education / Vocational Education
```

核心目标：

```text
交付一个手机端可打开、可录屏的 Web Agent demo，并跑通一条完整闭环：
Today -> Scheduled/Manual session -> Deep Dive -> 用户材料/公开材料源
-> Check-in -> History -> 提交材料。
```

核心策略：

```text
先做一条窄而深、可验证的任务链。
四类 session 抽象用于证明产品架构可复用，但 8/16 前不把四条线都做成完整工作流。
```

## 状态说明

```text
[ ] 未开始
[~] 进行中
[x] 已完成
[!] 阻塞 / 需要决策
```

## 不可妥协范围

必须保留：

- [x] Mobile-first Web demo 能在手机浏览器或移动端响应式视口打开。
- [x] `Today -> Deep Dive Workspace -> Check-in -> History` 闭环能端到端跑通。
- [x] 至少一个稳定材料源：用户上传/登记材料、公开 URL/public source，或明确标注的 fallback demo source。
- [x] Deep Dive 推荐理由能引用用户当前计划或个人偏好，而不是只靠固定查询词。
- [x] Scheduled Mode / Manual Mode 足够清楚，能解释产品交互模型。
- [x] Radar / Deep Dive / Weekly Studio / Opportunity Alignment 作为可复用 session template 出现在产品中。
- [x] 底部导航采用 `今日 / 历史 / 计划 / 我的`；原 `设置` 并入 `我的`。
- [x] 本地保存最小个人上下文：个人情况/简历摘要、工作/学习计划、材料源偏好、用户资料记录。
- [ ] README 写清楚怎么运行、点击路径是什么。
- [ ] 500 字项目介绍完成。
- [ ] Proposal PPT/PDF 完成。
- [ ] 60-90 秒 demo 视频完成。

时间紧时砍掉：

- [ ] 原生 iOS demo。
- [ ] 完整 JD Intelligence 工作流。
- [ ] 完整 Radar 端到端工作流。
- [ ] 完整 Weekly Studio 端到端工作流。
- [ ] 完整 Opportunity Alignment 端到端工作流。
- [ ] 简历编辑器。
- [ ] PDF annotation 持久化。
- [ ] 多模板配置 UI。
- [ ] 复杂 Agent Infra / AgentTeams 迁移。

## 第 1 天（2026-08-04）：产品定义与独立工作区

目标：

锁定产品方向，避免范围漂移。

任务：

- [x] 确认产品名：`圆周引擎 / Orbit Engine`。
- [x] 确认赛道：Boundless Agents / AI + Education / Vocational Education。
- [x] 确认竞赛产品不等同于个人 iOS Infra Agent。
- [x] 确认主要交付形态：mobile-first Web + FastAPI。
- [x] 创建独立工作区：`/home/maxh/Agent/GOAI`。
- [x] 从 infra 复制可复用后端和 iOS prototype 代码。
- [x] 创建后续窗口可读的项目记忆。
- [x] 创建产品定位文档。
- [x] 创建 demo 脚本文档。

输出：

- [x] `README.md`
- [x] `memory/PROJECT_MEMORY.md`
- [x] `submission/product_positioning.md`
- [x] `submission/demo_script.md`
- [x] `docs/competition_product_definition.md`
- [x] `docs/competition_execution_plan.md`

说明：

- 原生 iOS 作为参考和长期个人 App 方向保留，不作为 8/16 主交付路径。
- 后续实现优先从后端 API 检查和 mobile Web 壳开始。

## 第 2 天（2026-08-05）：后端闭环 API + 最小 Web 壳

目标：

把原第 2 天和第 3 天的基础工程压缩到一天。优先让后端达到可调试 demo 状态，然后创建最小 mobile-first Web 壳。

后端任务：

- [x] 从 `/home/maxh/Agent/GOAI/backend` 启动 FastAPI 后端。
- [x] 验证 `/api/health`。
- [x] 验证 `/api/today`。
- [x] 验证 `/api/sessions/today`。
- [x] 验证 `/api/sessions/mock`。
- [x] 验证 `/api/checkins`。
- [x] 验证 History/check-in 列表行为。
- [x] 确认普通 check-in 是否会更新 session 状态。
- [x] 找到或规划最小 session 状态更新方案。

Web 壳任务：

- [x] 创建 `/home/maxh/Agent/GOAI/web`。
- [x] 添加 `index.html`。
- [x] 添加 `app.js`。
- [x] 添加 `style.css`。
- [x] 创建最小页面结构：
  - [x] Today
  - [x] Research Workspace
  - [x] Check-in
  - [x] History
- [x] 保证 375px 移动端宽度基本可调试。

输出：

- [x] `docs/backend_api_demo_flow.md`
- [x] 后端 smoke command 说明。
- [x] Web demo API 调用列表。
- [x] 第一版 mobile Web 壳。

完成标准：

- 后端 demo-critical APIs 能被调用和调试。
- 能清楚说明 Web demo 会调用哪些 endpoint。
- 浏览器打开页面能看到完整 demo 结构，即使数据仍是 mock。

## 第 3 天（2026-08-06）：Mock 闭环 + 移动端调试 + iOS 交互迁移起步

目标：

在手机浏览器中跑通第一条 `Today -> Deep Dive Workspace -> Check-in -> History` mock 闭环，并开始把 Web 交互拉回原 iOS 前端结构。

任务：

- [x] Web 调用 `/api/sessions/today` 或 `/api/sessions/mock`。
- [x] 渲染 session 标题、领域、session type、suggested action、status。
- [x] 渲染 Deep Dive / Research payload 卡片。
- [x] 打开 Deep Dive Workspace。
- [x] 通过后端提交 check-in。
- [x] 在 History 显示提交后的 check-in。
- [x] 后端重启后闭环仍能工作。
- [x] 记录准确 demo 点击路径。
- [x] check-in 提交后可见地改变 session 状态或完成显示。
- [x] History 能展示最新 session/check-in，不需要手动改数据库。
- [x] 增加 loading 状态。
- [x] 增加 error 状态。
- [x] mock 数据使用时明确标注 Demo Mode。
- [x] 检查 375px 移动端宽度。
- [x] 检查 390px 移动端宽度。
- [x] 检查 430px 移动端宽度。
- [x] 按钮足够易点。
- [x] 文本不明显溢出。
- [x] FastAPI 直接托管 Web demo：`/demo`。
- [x] iPhone 通过 `http://172.20.10.4:8020/demo` 预览。
- [x] 修复刷新按钮导致 Demo Mode 的问题。
- [x] 底部导航改为 `今日 / 历史 / 设置`。
- [x] 移除独立 JD tab。
- [x] Manual Mode 补齐四个入口：Radar / Deep Dive / Opportunity Alignment / Weekly Studio。
- [x] Weekly Studio 复用 Sunday review / `research_feeder`，不新增后端 enum。
- [x] Web workspace 开始按照原 iOS SwiftUI 的 List / Section / NavigationLink 模式迁移。
- [x] Opportunity Alignment 迁移到通用命名下的原 JDIntelligence 层级：添加机会、机会库、机会详情、候选行动、能力画像、任务状态、Agent 讨论。

输出：

- [x] 第一版可录屏的端到端 mock demo。
- [x] `docs/demo_click_path.md`
- [x] Mobile-debuggable closed-loop demo。
- [x] `docs/day3_mobile_375.png`
- [x] `docs/day3_mobile_390.png`
- [x] `docs/day3_mobile_430.png`
- [x] `docs/day3_tabbed_today_390.png`
- [x] `docs/day3_ios_style_migration_390.png`
- [x] `docs/day3_four_session_mapping_390.png`

完成标准：

- `Today -> Deep Dive Workspace -> Check-in -> History` 不需要手动数据库编辑即可完成。
- 即使还没接真实 source，也能在手机竖屏视口录出当前闭环。
- Web 不再是单页长网页，而是开始遵循原 iOS 前端的递进结构。

## 第 4 天（2026-08-07）：Deep Dive 材料源 + 用户计划上下文

目标：

让主 demo 链路可信：Deep Dive 不只是随机推荐材料，而是能从用户材料、公开材料和个人计划上下文中生成一个可执行阅读/研究 session。

材料源优先级：

```text
1. 用户上传/登记材料：PDF、URL、手动材料卡。
2. 公开材料源：public URL、官方文档、GitHub README、文章、论文平台。
3. arXiv 仅作为 public source 示例之一，不作为产品边界。
4. 如果外部源失败，使用明确标注的 fallback demo material。
```

任务：

- [x] 添加后端 `MaterialSource` 抽象或最小 source adapter。
- [x] 支持最小用户材料入口：
  - [x] PDF metadata 登记或本地文件路径登记。
  - [x] URL 登记。
  - [x] 手动材料卡：title / source_type / summary / url_or_file_path。
- [ ] 支持公开材料源 fallback：
  - [ ] arXiv/public source adapter 作为可选 demo source。
  - [x] 外部请求失败时使用明确标注的 fallback demo material。
- [x] 解析或保存统一字段：
  - [x] title
  - [x] source_type
  - [x] authors / publisher / owner if available
  - [x] summary / abstract
  - [x] published date if available
  - [x] URL 或 file_path
  - [x] tags / categories
  - [x] fetched_at
- [x] 增加最小个人上下文本地记录：
  - [x] 个人情况 / 简历摘要。
  - [x] 当前工作/学习计划。
  - [x] 关注领域和材料源偏好。
  - [x] 最近 check-in 可被推荐逻辑引用。
- [x] 推荐逻辑支持从两类上下文生成材料选择理由：
  - [x] 用户定义侧：目标、领域、偏好、材料源。
  - [x] 当前计划侧：本周重点、当前任务、最近进度、下一步。
- [x] 将“固定查询词”改为“tracking keywords seeds”：
  - [x] 默认 demo 用户可以有示例 keywords。
  - [x] keywords 必须能解释为来自用户目标/计划，而不是产品写死。
- [x] 生成简单 `why_selected`，并明确引用 related_plan 或 user_preference。
- [x] 显示主材料和候选材料。
- [x] 显示 source 和 source link。
- [x] 显示 why selected。
- [x] 显示 reading goal。
- [x] 显示 30/60/90 分钟计划或所选时间预算。
- [x] 底部导航调整为：
  - [x] 今日
  - [x] 历史
  - [x] 计划
  - [x] 我的
- [x] 原 `设置` 内容并入 `我的`。
- [x] `计划` 页面最小可见：
  - [x] 当前目标。
  - [x] 本周重点。
  - [x] 当前任务/下一步。
  - [x] 材料推荐使用了哪些计划信息。
- [x] `我的` 页面最小可见：
  - [x] 个人情况/简历摘要。
  - [x] 领域偏好。
  - [x] 材料源偏好。
  - [x] 本地数据说明。
- [x] 显示 Deep Dive prompts：
  - [x] Input / Output
  - [x] Core method
  - [x] Evidence to inspect
  - [x] Relation to field
  - [x] Continue / track later / drop

输出：

- [x] `MaterialSource` adapter 或明确标注的 fallback source path。
- [x] 最小个人上下文/计划数据结构。
- [x] `计划` 和 `我的` 底部栏入口草版。
- [x] Source compliance note 草稿。
- [x] 可录屏 Deep Dive workspace。

完成标准：

- [x] Demo 能展示用户材料、公开材料源或明确标注的 fallback source。
- [x] 评委能在 10 秒内理解：Agent 选择这份材料，是因为它关联用户当前计划/偏好，而不是随机搜索结果。
- [x] 底部栏从 `今日 / 历史 / 设置` 过渡到 `今日 / 历史 / 计划 / 我的`。

## 第 5 天（2026-08-08）：轻量 Radar / Weekly Studio / Opportunity Alignment

目标：

用一天压缩完成三条非主链路的可见轻量能力，不把它们扩展成完整后端 + 前端 + check-in + history 工作流。

为什么重要：

- 证明产品不只是单一材料阅读 demo。
- 支撑四类 session 抽象的复用性。
- 保持轻量，避免抢走 Deep Dive 闭环优先级。

任务：

- [ ] 添加 Radar lightweight preview：
  - [ ] 目的：发现外部信号。
  - [ ] 示例来源：材料、repo、新闻、产品更新、比赛等。
  - [ ] 2-3 张 signal cards，并说明 `why it matters`。
- [ ] 添加 Weekly Studio lightweight preview：
  - [ ] 目的：归档、复盘、continue/track/drop、下周调整。
  - [ ] 如果已有最近 Deep Dive check-in，则显示摘要。
  - [ ] 示例 weekly output card。
- [ ] 添加 Opportunity Alignment lightweight preview：
  - [ ] 目的：把学习与外部需求对齐。
  - [ ] JD 只作为其中一种 subtype。
  - [ ] 至少包含一个非 JD 示例：比赛、benchmark/open problem、项目机会、市场/用户需求。
  - [ ] 显示建议下一步 session 或 track/ignore 判断。
- [ ] 三者都能从 Manual Mode 或 template gallery 进入。
- [ ] 如果未完整持久化，要标注为 lightweight template / preview workflow。

输出：

- [ ] Radar preview 可见。
- [ ] Weekly Studio preview 可见。
- [ ] Opportunity Alignment preview 可见。

完成标准：

- 评委能看懂三类非主 session 分别做什么，同时完整可运行闭环仍聚焦 Deep Dive。

## 第 6 天（2026-08-09）：闭环证据 + Scheduled/Manual Mode

目标：

合并原来的闭环证据和 Scheduled/Manual Mode 工作。让 Deep Dive 闭环可验证，同时展示产品更广的交互模型。

为什么重要：

- 手册看重完整任务链、验证和反馈。
- Scheduled Mode 证明产品降低启动成本。
- Manual Mode 保留用户自主性，适应真实生活变化。

任务：

- [ ] Check-in form 包含：
  - [ ] 做了什么
  - [ ] 关键洞察
  - [ ] 下一步
  - [ ] completed / partial status
- [ ] mobile Web demo 中 check-in 提交成功。
- [ ] session status 更新或可见反映完成。
- [ ] History 显示：
  - [ ] 日期
  - [ ] session type
  - [ ] source material
  - [ ] key insight
  - [ ] next action
- [ ] 增加简单验证证据：
  - [ ] session completed state
  - [ ] saved check-in timestamp
  - [ ] source/material reference
- [ ] 不需要手动数据库编辑。
- [ ] Today 显示 Scheduled Mode：
  - [ ] 推荐 session type
  - [ ] 推荐理由
  - [ ] weekly rhythm context
- [ ] Manual Mode selector 包含：
  - [ ] Radar
  - [ ] Deep Dive
  - [ ] Weekly Studio
  - [ ] Opportunity Alignment
- [ ] 用户能启动推荐的 Deep Dive session。
- [ ] 用户能手动选择 session templates。

输出：

- [ ] 闭环证据页面或状态。
- [ ] Today 支持 scheduled recommendation 和 manual override。

完成标准：

- Demo 能从 input/source 到 validation 跑完一条 Boundless-style Deep Dive 任务链。
- 评委能理解 Orbit Engine 既不是死板日历，也不是空白 todo app。

## 第 7 天（2026-08-10）：复用性领域映射与产品解释

目标：

在 PPT 前准备项目最强的复用价值证明：同一套四类 session 抽象能映射到多个领域。

这是产品/架构工作，不是完整后端工作流日。

任务：

- [ ] 起草 reusable architecture / domain mapping table：
  - [ ] 职业能力建设
  - [ ] 研究方向探索
  - [ ] 创作者 / 视觉 IP 运营
  - [ ] 创业 / 产品探索
  - [ ] 语言学习
- [ ] 每个领域映射：
  - [ ] Radar source
  - [ ] Deep Dive material
  - [ ] Opportunity Alignment source
  - [ ] Weekly Studio output
- [ ] 把表格加入 `submission/reusable_value.md` 或 draft doc。
- [ ] 写一段紧凑的 “why this is not a todo app” 解释，放入 About/Demo Notes。
- [ ] JD 保留为 Opportunity Alignment 的一种例子，而不是产品边界。
- [ ] 起草首次使用 onboarding / configuration flow：
  - [ ] 用户目标类型，例如转行、跳槽、考研、高考、考公、广泛探索、随便学学等。
  - [ ] 想学习 / 研究 / 探索的方向。
  - [ ] 需要跟踪哪些现实信息源，例如机会、比赛、高校、导师、材料、社区、政策、岗位要求等。
  - [ ] 每周节奏偏好和 manual override 原则。

输出：

- [ ] Domain mapping table draft。
- [ ] Reusable architecture explanation draft。

完成标准：

- 能清楚解释复用性，但不声称所有领域都已经完整实现。

## 第 8 天（2026-08-11）：移动端可复现性、失败处理与 Runbook

目标：

让 demo 在手机上可复现、可信。

任务：

- [ ] 从 clean start 启动后端。
- [ ] 从 clean start 启动 Web demo。
- [ ] 验证 fallback source path。
- [ ] 验证本地用户上下文记录：
  - [ ] 个人情况/简历摘要。
  - [ ] 当前工作/学习计划。
  - [ ] 用户材料记录。
  - [ ] 偏好/keywords seeds。
- [ ] 验证 browser console 无关键错误。
- [ ] 检查 375px / 390px / 430px 移动端宽度。
- [ ] 修复文本溢出和点击区域。
- [ ] 增加清晰提示：
  - [ ] source failure
  - [ ] missing data
  - [ ] demo/fallback source
  - [ ] local-only user context
  - [ ] learning-assistance boundary
- [ ] 更新 root `README.md` 当前运行说明。
- [ ] 添加 `docs/demo_runbook.md`。

输出：

- [ ] Mobile-ready demo candidate。
- [ ] `README.md`
- [ ] `docs/demo_runbook.md`

完成标准：

- 评审或开发者可以按 runbook 复现主 Deep Dive demo path。

## 第 9 天（2026-08-12）：交互逻辑优化与 iOS 风格美化

目标：

在 Web 前端向原 iOS 结构迁移后，专门用一天优化产品交互逻辑和视觉细节。

这不是功能扩张日。它存在的原因是：iPhone 录屏体验必须像一个完整 mobile app，而不是薄网页或 debug shell。

任务：

- [ ] 对照原 iOS 前端截图和 SwiftUI 结构检查 Web。
- [ ] 清理 Today：
  - [ ] 标题和副标题简洁。
  - [ ] Scheduled/Manual 在顶部。
  - [ ] 一个明确任务卡片。
  - [ ] 不出现 debug/proof widgets。
  - [ ] 首页没有长下拉。
- [ ] 清理底部导航：
  - [ ] 今日
  - [ ] 历史
  - [ ] 计划
  - [ ] 我的
  - [ ] 不出现 standalone JD tab。
  - [ ] 原设置项进入 `我的`，不再作为独立底部 tab。
- [ ] 清理 Workspace 逻辑：
  - [ ] 每个可点行都能进入有意义的页面。
  - [ ] 没有死卡片。
  - [ ] 除非明确标注为限制，否则不出现泛化 `Demo preview`。
  - [ ] check-in 只在合理位置出现。
- [ ] 清理 Manual Mode：
  - [ ] Radar
  - [ ] Deep Dive
  - [ ] Opportunity Alignment
  - [ ] Weekly Studio
  - [ ] 每个选择都会更新 Today task card。
- [ ] 移除或重写用户可见的个人语境词：
  - [ ] 不出现用户特定研发方向词。
  - [ ] 不把 JD 作为产品边界。
  - [ ] 使用通用的 `field`、`materials`、`sources`、`opportunities`、`ability profile`、`weekly rhythm`。
- [ ] 打磨 iPhone 视觉细节：
  - [ ] safe-area spacing
  - [ ] bottom tab spacing
  - [ ] tap target size
  - [ ] text wrapping
  - [ ] section/list density
  - [ ] Safari address-bar recording acceptability
- [ ] 验证 375px / 390px / 430px 移动端宽度。
- [ ] 美化后生成更新截图。

输出：

- [ ] iPhone-recordable UI candidate。
- [ ] 更新后的 screenshot set。
- [ ] 如果交互路径变化，更新 `docs/demo_click_path.md`。

完成标准：

- 产品能在 iPhone 上打开，并且足够接近现有 iOS 交互模型，能用于 60-90 秒竞赛视频录制。
- 该日之后的 UI 改动应限于 bug fix 或文案修正，不再做结构性 redesign。

## 第 10 天（2026-08-13）：Proposal PPT/PDF 草稿

目标：

创建官方 proposal deck 草稿。

任务：

- [ ] 创建 proposal deck。
- [ ] 包含：
  - [ ] 封面
  - [ ] 场景问题
  - [ ] 目标用户
  - [ ] 产品定义
  - [ ] session types
  - [ ] demo workflow
  - [ ] agent architecture
  - [ ] why not todo app
  - [ ] reusable architecture / domain mapping table 独立页
  - [ ] current progress
  - [ ] data/compliance
  - [ ] reusable value
  - [ ] roadmap
- [ ] 导出 draft PDF。

必须独立成页的 domain mapping table：

```text
Field / Domain
  -> Radar source
  -> Deep Dive material
  -> Opportunity Alignment source
  -> Weekly Studio output

Career capability building
Research direction exploration
Creator / visual IP operation
Startup / product exploration
Language learning
```

输出：

- [ ] `submission/proposal_draft.pptx` 或等价文件。
- [ ] `submission/proposal_draft.pdf`

完成标准：

- PPT 不依赖现场口头解释，也能讲清楚产品故事。

## 第 11 天（2026-08-14）：视频 dry run 与最终 bugfix 窗口

目标：

通过一次 dry-run 录制发现剩余产品/demo 问题，在还有时间时修掉阻塞项。

任务：

- [ ] 完整跑一次 dry-run recording。
- [ ] 识别 UI/demo blockers。
- [ ] 只修影响录屏闭环的 blocker。
- [ ] 不新增功能。
- [ ] 如有必要，更新 PPT screenshots。
- [ ] 导出 proposal final candidate PDF。
- [ ] 捕获或刷新 screenshot pack：
  - [ ] Today
  - [ ] Scheduled/Manual Mode
  - [ ] Deep Dive
  - [ ] History
  - [ ] four-session template gallery
  - [ ] domain mapping table

输出：

- [ ] Dry-run video。
- [ ] Final bugfix list。
- [ ] `submission/proposal.pdf` final candidate。

完成标准：

- 能完整录制视频，不出现失败步骤。

## 第 12 天（2026-08-15）：最终 demo 视频与材料冻结

目标：

录制最终 60-90 秒视频，并冻结所有提交材料。

任务：

- [ ] 冻结 demo path。
- [ ] 启动后端。
- [ ] 打开 mobile web viewport。
- [ ] 录制：
  - [ ] Today
  - [ ] Scheduled recommendation / Manual Mode 简要展示
  - [ ] 生成 Deep Dive Research Session
  - [ ] 展示 source/material
  - [ ] 打开 Deep Dive
  - [ ] 提交 check-in
  - [ ] 展示 History
- [ ] 添加简单字幕或 voiceover。
- [ ] 导出最终视频。
- [ ] 最终确认 proposal PDF。

输出：

- [ ] `submission/demo_video.*` 或 video link note。
- [ ] 可选 GIF/screenshots。
- [ ] `submission/proposal.pdf`

完成标准：

- 视频在 90 秒内证明一条完整任务链。

## 第 13 天（2026-08-16）：提交冻结

目标：

避免最后一刻破坏 demo。轻量文本材料、README、runbook 在这里最终确认，不再单独占一个开发日。

任务：

- [ ] 写完/确认 500 字项目介绍。
- [ ] 写完/确认 data and compliance note。
- [ ] 写完/确认 open/reusable contribution note。
- [ ] 写完/确认 current progress summary。
- [ ] 写完/确认 known limitation and roadmap summary。
- [ ] 更新 root `README.md`。
- [ ] 添加或最终确认 `docs/demo_runbook.md`。
- [ ] 从 clean start 启动后端。
- [ ] 从 clean start 启动 Web demo。
- [ ] 验证手机/移动端视口。
- [ ] 验证 README instructions。
- [ ] 验证 PPT 和 demo video 一致。
- [ ] 验证 data/source/compliance 说法准确。
- [ ] 如需要，打包 repository 或 zip。
- [ ] 提交：
  - [ ] 500 字项目介绍
  - [ ] proposal PPT/PDF
  - [ ] demo video/prototype link
  - [ ] repository/zip if included

输出：

- [ ] Final submission package。
- [ ] `submission/project_intro_500.md`
- [ ] `submission/compliance_note.md`
- [ ] `submission/reusable_value.md`
- [ ] `submission/current_progress.md`
- [ ] `docs/demo_runbook.md`

完成标准：

- 没有关键路径事项遗留。

## 进度记录

本节记录已完成事项和关键决策。

### 2026-08-03

- [x] 创建独立 GOAI workspace。
- [x] 从 infra 复制 backend 和 iOS prototype。
- [x] 创建产品定位文档。
- [x] 创建 demo script 文档。
- [x] 创建 project memory 文档。
- [x] 决定竞赛交付面为 mobile-first Web，而不是原生 iOS。
- [x] 将操作规则写入 project memory：以后完成 GOAI 任务后，必须更新本计划 checklist 和进度记录。
- [x] 压缩原第 2 天 / 第 3 天：后端闭环 API audit/fix + 最小 mobile Web shell。
- [x] 重新平衡第 2-13 天计划：优先 mock 闭环、移动端可调试状态、public source、Agent-guided session 质量、可复现性，然后准备提交材料和视频。
- [x] 产品命名为 `圆周引擎 / Orbit Engine`。
- [x] 重新平衡计划，最初给 Radar、Deep Dive、Weekly Studio、Opportunity Alignment 各一天 debug。
- [x] 将 Scheduled Mode / Manual Mode 加入实现计划。
- [x] 增加 PPT 独立页要求：reusable architecture / domain mapping table。
- [x] 根据 Boundless handbook 08 和 10 修正范围：8/16 前只有 Deep Dive 必须是深度可运行闭环；Radar / Weekly Studio / Opportunity Alignment 作为 template 和 domain-mapping proof 展示。
- [x] 调整第 5/6 天：Radar、Weekly Studio、Opportunity Alignment 压缩为一个轻量功能日；闭环证据和 Scheduled/Manual Mode 合并为一天。
- [x] 完成第 2 天后端环境：创建 `backend/venv`，安装 requirements，FastAPI app import 成功，本地 uvicorn HTTP smoke 覆盖 `/api/health`、`/api/today`、`/api/sessions/today`、`/api/sessions/mock`、`/api/checkins`。
- [x] 确认 completion 行为：直接 `POST /api/checkins` 只保存 check-in；demo 应使用 `POST /api/sessions/{session_id}/completion/confirm`，因为它会同时更新 session 状态并创建 check-in。
- [x] 添加后端 CORS middleware。
- [x] 创建第一版 mobile Web shell，包含 Today、Scheduled/Manual Mode、Research Workspace、Check-in、History 和四类 session template preview。
- [x] 添加 `docs/backend_api_demo_flow.md`，包含运行命令、endpoint 列表、smoke 结果和 Web demo API contract。

### 2026-08-04

- [x] 完成第 3 天 mock loop 和移动端调试。
- [x] Web demo 固定到 Deep Dive demo date `2026-08-06`，因为该周四在现有 coordinator 中对应 `research_feeder / Deep Dive`。
- [x] 添加 URL overrides：`api`、`date`、`auto=1`，避免调试依赖固定端口或真实日期。
- [x] 添加过可见 Loop Evidence 状态：session status、check-in saved、History refreshed；后续作为用户界面 debug 组件移除。
- [x] 使用 Chromium headless 验证浏览器 DOM flow：`API OK`、`研究阅读启动`、`completed`、`闭环完成`、`Check-in saved` 和 History check-in 文案出现。
- [x] 生成移动端截图：
  - `docs/day3_mobile_375.png`
  - `docs/day3_mobile_390.png`
  - `docs/day3_mobile_430.png`
- [x] 添加 `docs/demo_click_path.md`。
- [x] 手动 review 后修复可用性：Today card 整卡可点，不只内部按钮可点，并添加 tap hint。
- [x] 修复 iPhone preview：默认 API base 跟随当前 page hostname + 8020，避免 iPhone 刷新后退回 `127.0.0.1`。
- [x] 更强 iPhone preview 修复：FastAPI 直接在 `/demo` 托管 Web demo，iPhone 使用同源 URL `http://172.20.10.4:8020/demo`。
- [x] 修复刷新按钮 bug：移除会把 click event 当 API path 传入的错误 handler；refresh 现在通过 wrapper 调用 `loadToday()`。
- [x] 交互修正：Web 从单页堆叠改为递进式 flow：Home 显示 Today/Mode/History，点击 Today card 进入 Workspace detail view。
- [x] iOS 对齐修正：Web navigation 改为底部 tab `今日 / 历史 / 设置`，移除 standalone JD tab，History 独立成 tab，Check-in/Workspace 放到 detail view，移除用户可见 `Loop Evidence`。
- [x] Manual Mode 修正：Scheduled/Manual 位于 Today 顶部；Manual 显示 Radar / Deep Dive / Opportunity Alignment / Weekly Studio choices，并更新 Today task card。
- [x] 生成更新截图 `docs/day3_tabbed_today_390.png`。
- [x] infra/iOS 迁移修正：workspace layout 更接近原 SwiftUI List/Section/NavigationLink。Deep Dive 使用 `目标 / 计划 / 材料 / 完成标准`；Radar 使用 `信号 / Agent 讨论`；Opportunity Alignment 使用 `概览 / 工作区 / Agent 讨论`。
- [x] 生成迁移截图 `docs/day3_ios_style_migration_390.png`。
- [x] Manual 映射修正：展示四类产品 session type：Radar、Deep Dive、Opportunity Alignment、Weekly Studio。Weekly Studio 复用 Sunday review / `research_feeder`，不新增后端 enum。
- [x] 命名修正：Web 用户可见标签采用比赛产品名和通用文案；尽量移除个人研究方向词和 JD-as-product-boundary 文案。
- [x] 迁移 pass：Manual 映射为 `Radar -> tech_radar`、`Deep Dive -> research_feeder`、`Opportunity Alignment -> jd_analysis`、`Weekly Studio -> Sunday review / research_feeder`。Web workspace 条目映射到原 iOS List/Section/NavigationLink 风格，并且每一行都能打开详情页。
- [x] 添加截图 `docs/day3_four_session_mapping_390.png`。
- [x] Opportunity Alignment 迁移 pass：把原占位详情页扩展为原 iOS JDIntelligence 层级的通用产品版本：添加机会、机会库、机会详情、候选行动、行动文件夹、行动详情、能力画像、任务状态/Period、Agent 讨论。
- [x] iOS 视觉修正：mobile Web UI 调整为更接近 iOS system style，包括 large title、系统灰背景、grouped task card、iOS-like segmented control、半透明 bottom tab bar、CSS tab icons。
- [x] 生成更新 iOS-style 截图 `docs/day3_ios_style_today_390.png`。
- [x] 将 `docs/13_day_competition_plan.md` 整理为中文版：主结构、日程标题、任务说明、输出和完成标准均改为中文；保留必要英文产品名、技术名词、API 路径和文件名。
- [x] 将第 1-13 天对应到实际日期：2026-08-04 至 2026-08-16，其中 2026-08-04 为第 1 天。

### 2026-08-05

- [x] 修正第 4 天产品范围：从 `arXiv/public source` 单一论文源，改为 `MaterialSource` 抽象。
- [x] 明确 arXiv 仅作为 public source 示例之一，不作为产品边界。
- [x] 将用户上传/登记资料加入第 4 天：PDF metadata、本地文件路径、URL、手动材料卡。
- [x] 将个人情况/简历摘要、当前工作/学习计划、领域偏好、材料源偏好加入最小本地上下文。
- [x] 明确 Deep Dive 推荐理由要引用用户当前计划或个人偏好，而不是只靠固定查询词。
- [x] 将“初始查询词”调整为 `tracking keywords seeds`：来自用户目标和当前计划，可被用户配置。
- [x] 将底部导航目标改为 `今日 / 历史 / 计划 / 我的`，原 `设置` 并入 `我的`。
- [x] 将本地用户资料、用户偏好和计划记忆的验证安排到第 8 天。
- [x] 完成第 4 天核心实现：新增 `user_context` schema/service/API，本地 SQLite 保存 profile、plan、preferences 和 materials。
- [x] 新增 `/api/user-context` 和 `/api/user-context/materials`。
- [x] 扩展 `ResearchFeederPayload`：新增 `materials`、`primary_material_id`、`candidate_material_ids`、`recommendation_context`、`user_profile`、`active_plan`、`user_preferences`。
- [x] Deep Dive mock generation 改为从用户上下文读取材料和计划，`why_selected` 引用当前计划与偏好。
- [x] 修复数据库相对路径解析：`../data/infra_agent.db` 现在稳定解析到 GOAI workspace 的 `data/infra_agent.db`。
- [x] Web 底部栏调整为 `今日 / 历史 / 计划 / 我的`，原 `设置` 内容并入 `我的`。
- [x] Web Deep Dive 工作区显示主材料、候选材料、推荐理由、时间预算和 source/local note。
- [x] 新增 `计划` 页面：长期目标、本周重点、当前任务、下一步、tracking keywords。
- [x] 新增 `我的` 页面：个人情况、背景摘要、阶段、领域偏好、材料源偏好、本地数据说明。
- [x] 新增 `docs/source_compliance_note.md`。
- [x] 生成 Day4 截图 `docs/day4_material_context_390.png`。
- [x] 验证：FastAPI import 成功，`/api/health`、`/api/user-context`、`/api/sessions/today?date=2026-08-06` TestClient smoke 通过。
- [x] 验证：`node --check web/app.js` 通过。
- [x] 验证：Chromium headless 打开 `/demo`，DOM 出现 `API OK`、`主材料`、具体材料标题、推荐理由、`计划` 和 `我的`。
- [ ] 未完成：live arXiv/public source adapter。当前阶段保留为可选 public source 后续任务，主线不依赖它。
- [!] 测试限制：`venv/bin/python -m pytest -q` 未运行成功，因为当前 venv 未安装 `pytest`。
- [x] 根据用户反馈修正 Day4 交互结构：Deep Dive 卡片点击后先进入“进行中/未完成 + 新建”队列页，而不是直接进入工作区。
- [x] 新增新建 Deep Dive 入口：使用 PDF、登记 URL、手动材料卡；当前保存 metadata，后续可接真实文件上传/网页抓取。
- [x] 其他 session 也调整为类似结构：当前工作区 + 新建入口。
- [x] 移除 Deep Dive 详情页里的“当前任务 / 阅读目标 / 选择理由 / 30/60/90”伪点击入口，改为静态信息块。
- [x] 去掉 Deep Dive 详情页候选材料入口，只保留主材料入口。
- [x] Check-in 不再裸露在 Deep Dive 外层；现在放在完成标准下方的 `Check-in` 按钮内。
- [x] Agent Guidance 不再作为到处递归出现的 fallback；现在是 Deep Dive 完成标准下方的明确按钮，负责生成 Check-in 草稿。
- [x] Agent Guidance 草稿支持一键带入 Check-in 表单，用户可继续修改后写入 History。
- [x] `计划` / `我的` 在旧后端返回 404 时会使用本地 fallback context，不再把 404 裸露给用户；重启新后端后使用 SQLite 用户上下文。
- [x] 生成修正截图 `docs/day4_deep_dive_queue_390.png`。
- [x] 验证：`node --check web/app.js` 通过；Chromium headless DOM 出现 `API OK`、`进行中 / 未完成`、`新建 Deep Dive`、`计划`、`我的`。

### 2026-08-06

- [x] 根据用户决策停止继续扩展 Web 前端；Web 后续仅作为后端 API smoke / 兜底演示，不再作为主提交展示面。
- [x] 主展示面切回 iOS 原生 App + FastAPI 后端。
- [x] 新增 11 天双线并行计划：`docs/11_day_ios_native_dual_track_plan.md`。
- [x] 新计划每天均匀分配两条线任务：开发线 + 文档/PPT/PDF 线。
- [x] 在 GOAI 中创建竞赛专用分支 `competition/ios-native-boundless`，后续不在 `/home/maxh/Agent/infra` 中做竞赛开发。
- [x] 从 `/home/maxh/Agent/infra` 同步原生 iOS / FastAPI 代码基线到 `/home/maxh/Agent/GOAI`，未修改 infra 原目录。
- [x] 完成 11 天计划 Day1 开发线：冻结 Web、确认 iOS 复用范围、确定底部栏、列出 Day2 endpoint。
- [x] 创建 `docs/ios_native_migration_checklist.md`。
