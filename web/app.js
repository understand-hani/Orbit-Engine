const params = new URLSearchParams(window.location.search);
const DEFAULT_API_BASE =
  window.location.hostname && window.location.hostname !== "localhost"
    ? `${window.location.protocol}//${window.location.hostname}:8020/api`
    : "http://127.0.0.1:8020/api";
const savedApiBase = localStorage.getItem("orbit_api_base");
const savedApiBaseIsLocalOnly = savedApiBase && /\/\/(127\.0\.0\.1|localhost)(:|\/)/.test(savedApiBase);
const shouldIgnoreSavedApi =
  window.location.hostname &&
  window.location.hostname !== "localhost" &&
  window.location.hostname !== "127.0.0.1" &&
  savedApiBaseIsLocalOnly;
const API_BASE = params.get("api") || (shouldIgnoreSavedApi ? null : savedApiBase) || DEFAULT_API_BASE;
const DEMO_DEEP_DIVE_DATE = params.get("date") || localStorage.getItem("orbit_demo_date") || "2026-08-06";
const AUTO_COMPLETE = params.get("auto") === "1";

const manualSessions = [
  {
    id: "radar",
    label: "Radar",
    date: "2026-08-04",
    title: "Radar",
    subtitle: "发现外部信号、趋势、论文、repo 与机会。",
    lightweight: true,
  },
  {
    id: "deep_dive",
    label: "Deep Dive",
    date: DEMO_DEEP_DIVE_DATE,
    title: "Deep Dive",
    subtitle: "深入处理一篇材料，形成判断、证据和下一步。",
    lightweight: false,
  },
  {
    id: "alignment",
    label: "Opportunity Alignment",
    date: "2026-08-05",
    title: "Opportunity Alignment",
    subtitle: "把学习与外部机会、评价标准和现实需求对齐。",
    lightweight: true,
  },
  {
    id: "weekly_studio",
    label: "Weekly Studio",
    date: "2026-08-09",
    title: "Weekly Studio",
    subtitle: "复盘本周记录，归档收获，并调整下一轮节奏。",
    lightweight: true,
  },
];

const state = {
  session: null,
  mode: params.get("manual") ? "manual" : "scheduled",
  manualSelection: params.get("manual") || "deep_dive",
  isSubmitting: false,
};

const $ = (id) => document.getElementById(id);

function setStatus(text, ok = false) {
  const el = $("apiStatus");
  el.textContent = text;
  el.classList.toggle("ok", ok);
}

function labelTask(taskType) {
  const labels = {
    tech_radar: "Radar",
    research_feeder: "Deep Dive",
    jd_analysis: "Opportunity Alignment",
  };
  return labels[taskType] || taskType;
}

function displaySession() {
  if (state.mode === "manual") {
    const selected = manualSessions.find((item) => item.id === state.manualSelection);
    if (selected) {
      return {
        typeLabel: selected.title,
        title: selected.title,
        subtitle: selected.subtitle,
        isMainLoop: selected.id === "deep_dive",
      };
    }
  }
  return {
    typeLabel: labelTask(state.session?.task_type || ""),
    title: "Deep Dive",
    subtitle: "深入处理一份材料，形成判断、证据和下一步。",
    isMainLoop: state.session?.task_type === "research_feeder",
  };
}

function sessionDateForMode() {
  if (state.mode === "scheduled") return DEMO_DEEP_DIVE_DATE;
  const selected = manualSessions.find((item) => item.id === state.manualSelection);
  return selected?.date || DEMO_DEEP_DIVE_DATE;
}

function showView(viewId) {
  document.querySelectorAll(".view").forEach((view) => view.classList.remove("active"));
  $(viewId).classList.add("active");
  document.querySelectorAll("[data-tab]").forEach((tab) => tab.classList.remove("active"));
  document.querySelector(`[data-tab="${viewId}"]`)?.classList.add("active");
  window.scrollTo({ top: 0, behavior: "smooth" });
}

async function api(path, options = {}) {
  const response = await fetch(`${API_BASE}${path}`, {
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
    ...options,
  });
  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`${response.status} ${detail}`);
  }
  return response.json();
}

function renderManualPicker() {
  $("manualPicker").innerHTML = manualSessions
    .map(
      (item) => `
        <button class="${item.id === state.manualSelection ? "active" : ""}" type="button" data-manual="${item.id}">
          <strong>${item.label}</strong>
          <small>${item.lightweight ? "preview" : "main loop"}</small>
        </button>
      `
    )
    .join("");

  document.querySelectorAll("[data-manual]").forEach((button) => {
    button.addEventListener("click", async () => {
      state.manualSelection = button.dataset.manual;
      renderManualPicker();
      await loadToday();
    });
  });
}

function renderTodayCard(session) {
  const display = displaySession();
  $("todayCard").className = "task-card clickable";
  $("todayCard").innerHTML = `
    <div class="task-card-head">
      <span class="tag">${display.typeLabel}</span>
      <span class="status">${session.status}</span>
    </div>
    <h2>${display.title}</h2>
    <p>${display.subtitle}</p>
    <div class="tag-row">
      <span>${session.session_mode}</span>
      <span>${session.date}</span>
      <span>${display.isMainLoop ? "main loop" : "workspace"}</span>
    </div>
    <p class="tap-hint">点击进入工作区</p>
  `;
  $("todayCard").onclick = openWorkspace;
}

function renderWorkspace() {
  const session = state.session;
  if (!session) return;

  const payload = session.payload || {};
  const context = payload.research_context;
  const pack = payload.reading_pack;
  const digest = payload.digest;
  const criteria = session.completion?.criteria || [];
  const display = displaySession();
  const isMainLoop = display.isMainLoop;

  $("detailType").textContent = display.typeLabel;
  $("detailTitle").textContent = display.title;
  $("workspaceStatus").textContent = session.status;
  $("checkinPanel").classList.toggle("hidden", !isMainLoop);

  if (state.mode === "manual" && state.manualSelection === "weekly_studio") {
    renderWeeklyStudioWorkspace();
    return;
  }

  if (session.task_type === "tech_radar") {
    renderRadarWorkspace(session, digest);
    return;
  }

  if (session.task_type === "jd_analysis") {
    renderAlignmentWorkspace(session);
    return;
  }

  renderResearchWorkspace(session, criteria);
}

function renderResearchWorkspace(session, criteria) {
  $("workspace").className = "ios-list";
  $("workspace").innerHTML = `
    ${sectionIntro("Deep Dive", "深入处理一份材料，形成输入输出、核心证据、方向判断和下一步行动。")}
    ${sectionHeader("目标")}
    ${navRow("当前任务", "选择一份主材料，并围绕一个具体问题完成深入处理。", "target")}
    ${navRow("阅读目标", "明确材料的输入、输出、核心方法、证据、局限和是否值得继续。", "reading_goal")}
    ${sectionHeader("计划")}
    ${navRow("选择理由", "根据用户定义的长期目标、当前阶段和外部现实信号选择材料。", "why_selected")}
    ${navRow("30 / 60 / 90 分钟路径", "按时间预算拆分阅读深度和产出。", "timebox")}
    ${sectionHeader("材料")}
    ${navRow("主材料", "等待接入用户配置领域下的真实来源。", "primary_material")}
    ${navRow("候选材料", "作为对照或后续追踪材料。", "candidate_material")}
    ${sectionHeader("完成标准")}
    ${navRow("Completion criteria", criteria.map((item) => item.description).join("；") || "完成精读段落和下一步判断。", "criteria")}
  `;
  bindDetailRows();
}

function renderRadarWorkspace(session, digest) {
  $("workspace").className = "ios-list";
  $("workspace").innerHTML = `
    ${sectionIntro("Radar", digest?.summary || "从用户指定的信息源中发现外部信号、变化趋势和可行动线索。")}
    ${sectionHeader("信号")}
    ${navRow("核心信号", "来自信息源的新变化：机会、政策、论文、产品、课程、岗位或社区动态。", "radar_signal")}
    ${navRow("为什么重要", "过滤噪声，判断哪些外部变化和用户目标真正相关。", "radar_why")}
    ${sectionHeader("Agent 讨论")}
    ${navRow("和 Agent 讨论", "围绕一个信号追问技术实质、风险和下一步。", "radar_discuss")}
  `;
  bindDetailRows();
}

function renderAlignmentWorkspace(session) {
  $("workspace").className = "ios-list";
  $("workspace").innerHTML = `
    ${sectionIntro("Opportunity Alignment", "把学习、探索或能力建设与外部机会、评价标准和现实需求对齐。")}
    ${sectionHeader("概览")}
    <div class="metric-row">
      <div><strong>2</strong><span>机会</span></div>
      <div><strong>1</strong><span>关注</span></div>
      <div><strong>1</strong><span>高相关</span></div>
      <div><strong>2</strong><span>行动</span></div>
    </div>
    ${sectionHeader("工作区")}
    ${navRow("添加机会", "粘贴岗位、比赛、项目、学校、导师、考试或其他现实线索。", "add_opportunity")}
    ${navRow("机会库", "查看已收集的外部机会和评价标准。", "opportunity_library")}
    ${navRow("候选行动", "把外部需求转换成学习、作品或准备动作。", "candidate_actions")}
    ${navRow("能力画像", "查看当前能力证据与差距。", "skill_profile")}
    ${navRow("任务状态", "把候选行动反哺到当前周期。", "task_state")}
    ${sectionHeader("Agent 讨论")}
    ${navRow("和 Agent 讨论", "讨论匹配、风险、能力差距和下一步。", "alignment_discuss")}
  `;
  bindDetailRows();
}

function renderWeeklyStudioWorkspace() {
  $("workspace").className = "ios-list";
  $("workspace").innerHTML = `
    ${sectionIntro("Weekly Studio", "复盘本周记录、归档收获、调整下周节奏，并决定继续、暂停或换方向。")}
    ${sectionHeader("复盘")}
    ${navRow("本周摘要", "汇总本周完成的 Radar、Deep Dive 和 Alignment 记录。", "weekly_summary")}
    ${navRow("继续 / 暂停 / 放弃", "判断哪些方向值得继续投入，哪些需要暂停或丢弃。", "continue_pause_drop")}
    ${sectionHeader("归档")}
    ${navRow("知识归档", "把有价值的材料、洞察和行动沉淀到长期档案。", "archive")}
    ${navRow("能力更新", "更新能力画像、证据和下一步缺口。", "ability_update")}
    ${sectionHeader("下周")}
    ${navRow("下周节奏", "确认下一轮 scheduled sessions 的重点和信息源。", "next_week")}
  `;
  bindDetailRows();
}

function sectionIntro(title, subtitle) {
  return `
    <section class="ios-section plain">
      <h3>${title}</h3>
      <p>${subtitle}</p>
    </section>
  `;
}

function sectionHeader(title) {
  return `<p class="ios-section-title">${title}</p>`;
}

function navRow(title, subtitle, detailId) {
  return `
    <button class="ios-row" type="button" data-detail="${detailId}" data-title="${title}" data-subtitle="${subtitle}">
      <div>
        <strong>${title}</strong>
        <small>${subtitle}</small>
      </div>
      <span>›</span>
    </button>
  `;
}

function cleanDisplayText(text = "") {
  return text
    .replaceAll("调试闭环", "任务闭环")
    .replaceAll("论文源", "材料源")
    .replaceAll("论文", "材料");
}

function bindDetailRows() {
  document.querySelectorAll("[data-detail]").forEach((row) => {
    row.addEventListener("click", () => {
      openItemDetail(row.dataset.title, row.dataset.subtitle, row.dataset.detail);
    });
  });
}

function openItemDetail(title, subtitle, detailId) {
  $("itemDetailType").textContent = displaySession().typeLabel;
  $("itemDetailTitle").textContent = title;
  $("itemDetailBody").innerHTML = detailContentFor(title, subtitle, detailId);
  bindDetailRows();
  showView("itemDetailView");
}

function detailContentFor(title, subtitle, detailId) {
  const content = {
    add_opportunity: `
      ${sectionHeader("添加方式")}
      ${navRow("手动录入", "粘贴或输入一条真实机会、评价标准或外部需求。", "opportunity_manual_form")}
      ${navRow("图片/截图导入", "后续用于从截图中提取结构化机会信息。", "opportunity_image_import")}
      ${sectionHeader("说明")}
      ${sectionIntro("机会不是只指岗位", "它可以是比赛、学校、导师、项目、考试、社区活动、市场需求或任何能反向校准学习方向的现实信号。")}
    `,
    opportunity_manual_form: `
      ${sectionHeader("机会")}
      <div class="form-card">
        <label>来源<input value="示例来源" /></label>
        <label>标题<input value="目标机会 / 评价标准 / 现实需求" /></label>
        <label>地点或范围<input value="线上 / 本地 / 全国 / 海外" /></label>
        <label>正文<textarea rows="5">在这里粘贴机会描述、要求、评价标准或现实约束。</textarea></label>
        <button class="primary" type="button">保存机会</button>
      </div>
    `,
    opportunity_image_import: `
      ${sectionHeader("导入")}
      ${sectionIntro("图片导入", "对应 iOS 的截图导入入口。当前 Web 先保留入口结构，后续接 OCR/多模态提取。")}
    `,
    opportunity_library: `
      ${sectionHeader("条目")}
      ${navRow("机会 A：高相关方向样例", "高相关 · watching · 需要作品证据", "opportunity_entry_a")}
      ${navRow("机会 B：长期追踪样例", "medium · track later · 需要补足基础能力", "opportunity_entry_b")}
    `,
    opportunity_entry_a: opportunityEntryDetail("高相关方向样例"),
    opportunity_entry_b: opportunityEntryDetail("长期追踪样例"),
    candidate_actions: `
      ${sectionHeader("筛选")}
      <div class="segmented static"><button class="active" type="button">全部</button><button type="button">高</button><button type="button">中</button><button type="button">低</button></div>
      ${sectionHeader("文件夹")}
      ${navRow("建议", "2", "action_folder_suggested")}
      ${navRow("已接受", "0", "action_folder_accepted")}
      ${navRow("已延后", "0", "action_folder_deferred")}
      ${navRow("已拒绝", "0", "action_folder_rejected")}
      ${navRow("已转任务", "1", "action_folder_converted")}
      ${sectionHeader("建议行动")}
      ${navRow("补齐一份可展示产出", "high · 建议本周转为 Deep Dive 或 Weekly Studio 输出", "action_detail_output")}
      ${navRow("追踪一个外部评价标准", "medium · 下次 Radar 继续观察", "action_detail_signal")}
    `,
    action_folder_suggested: actionFolder("建议"),
    action_folder_accepted: actionFolder("已接受"),
    action_folder_deferred: actionFolder("已延后"),
    action_folder_rejected: actionFolder("已拒绝"),
    action_folder_converted: actionFolder("已转任务"),
    action_detail_output: candidateActionDetail("补齐一份可展示产出"),
    action_detail_signal: candidateActionDetail("追踪一个外部评价标准"),
    skill_profile: `
      ${sectionHeader("快照")}
      ${sectionIntro("能力画像", "围绕用户目标整理当前能力、证据、差距和优先级。")}
      <div class="labeled-list">
        <div><span>能力数</span><strong>4</strong></div>
        <div><span>高优先级缺口</span><strong>1</strong></div>
      </div>
      ${sectionHeader("能力")}
      ${navRow("核心能力 A", "目标: advanced · 当前: intermediate · high", "skill_detail_a")}
      ${navRow("核心能力 B", "目标: intermediate · 当前: beginner · medium", "skill_detail_b")}
    `,
    skill_detail_a: skillDetail("核心能力 A"),
    skill_detail_b: skillDetail("核心能力 B"),
    task_state: `
      ${sectionHeader("Period")}
      ${navRow("本周执行周期", "3 个 session · 2 个已完成 · 1 个待复盘", "period_current")}
      ${navRow("下周准备周期", "待 Weekly Studio 生成", "period_next")}
    `,
    period_current: periodDetail("本周执行周期"),
    period_next: periodDetail("下周准备周期"),
    alignment_discuss: chatDetail("Opportunity Alignment"),
  };

  return (
    content[detailId] ||
    `
      ${sectionIntro(title, subtitle)}
      ${sectionHeader("Agent guidance")}
      ${navRow("下一步问题", guidanceFor(detailId), `${detailId}_question`)}
    `
  );
}

function opportunityEntryDetail(title) {
  return `
    ${sectionHeader("机会")}
    ${sectionIntro(title, "这是机会详情页，对应 iOS 的 JDEntryDetailView，但比赛版用通用机会语言。")}
    <div class="labeled-list">
      <div><span>来源</span><strong>示例来源</strong></div>
      <div><span>范围</span><strong>线上 / 本地</strong></div>
      <div><span>优先级</span><strong>high</strong></div>
      <div><span>状态</span><strong>watching</strong></div>
    </div>
    ${sectionHeader("偏好")}
    ${navRow("关注", "标记为持续关注。", "preference_watch")}
    ${navRow("高相关", "标记为高相关机会。", "preference_high")}
    ${sectionHeader("要求")}
    ${sectionIntro("能力与证据要求", "提取硬性要求、加分项、新关键词或评价标准。")}
    ${sectionHeader("Agent 分析")}
    ${navRow("分析并推荐行动", "生成匹配度、风险、能力差距和候选行动。", "analyze_opportunity")}
    ${sectionHeader("风险信号")}
    ${sectionIntro("风险", "识别不匹配、时间窗口、投入成本、目标漂移等风险。")}
    ${sectionHeader("能力差距")}
    ${sectionIntro("差距", "拆分为必须补足、可训练和暂时忽略的差距。")}
    ${sectionHeader("需要补的证据")}
    ${sectionIntro("证据", "明确后续作品、记录、材料或成果证明。")}
  `;
}

function actionFolder(title) {
  return `
    ${sectionHeader(title)}
    ${navRow("补齐一份可展示产出", "high · 可转任务", "action_detail_output")}
    ${navRow("追踪一个外部评价标准", "medium · 下次 Radar 观察", "action_detail_signal")}
  `;
}

function candidateActionDetail(title) {
  return `
    ${sectionHeader("行动")}
    ${sectionIntro(title, "对应 iOS 的 CandidateActionDetailView。")}
    <div class="labeled-list">
      <div><span>优先级</span><strong>high</strong></div>
      <div><span>状态</span><strong>suggested</strong></div>
      <div><span>建议时段</span><strong>next session</strong></div>
    </div>
    ${sectionHeader("决策")}
    ${navRow("接受", "把该行动纳入下一轮计划。", "action_accept")}
    ${navRow("延后", "保留但不进入本周。", "action_defer")}
    ${navRow("拒绝", "从当前周期移除。", "action_reject")}
    ${navRow("转为任务", "转换为可执行任务。", "action_convert")}
  `;
}

function skillDetail(title) {
  return `
    ${sectionHeader("技能")}
    ${sectionIntro(title, "对应 iOS 的 SkillStackView 中的技能条目。")}
    <div class="labeled-list">
      <div><span>类别</span><strong>core</strong></div>
      <div><span>当前等级</span><strong>intermediate</strong></div>
      <div><span>目标等级</span><strong>advanced</strong></div>
      <div><span>优先级</span><strong>high</strong></div>
    </div>
    ${sectionHeader("证据")}
    ${sectionIntro("已有证据", "这里列出用户已完成的材料、作品、记录或结果。")}
    ${sectionHeader("差距说明")}
    ${sectionIntro("Gap notes", "说明还缺什么，以及下一步如何补齐。")}
  `;
}

function periodDetail(title) {
  return `
    ${sectionHeader("Period")}
    ${sectionIntro(title, "对应 iOS TaskStateView 的 Period 详情入口。")}
    ${sectionHeader("Session")}
    ${navRow("Radar", "发现外部信号", "period_radar")}
    ${navRow("Deep Dive", "深入处理材料", "period_deep_dive")}
    ${navRow("Weekly Studio", "归档与调整", "period_weekly")}
  `;
}

function chatDetail(context) {
  return `
    ${sectionHeader("历史")}
    ${navRow("保存讨论到历史", "把本次 Agent 对话写入 History。", "save_discussion")}
    ${sectionHeader("讨论")}
    <div class="chat-list">
      <div class="chat-bubble agent"><strong>Agent</strong><p>我可以讨论匹配、风险、能力差距、候选行动和当前任务状态。</p></div>
      <div class="chat-bubble user"><strong>你</strong><p>请帮我判断这条机会下一步要不要继续投入。</p></div>
      <div class="chat-bubble agent"><strong>Agent</strong><p>先看它是否和你的目标、时间预算和可产出证据匹配。</p></div>
    </div>
    <div class="chat-input"><input value="输入你的问题..." /><button type="button">发送</button></div>
  `;
}

function guidanceFor(detailId) {
  const guidance = {
    target: "这一步要判断材料输入、输出、核心方法和是否值得继续。",
    reading_goal: "优先读摘要、方法图、实验设置和局限性。",
    why_selected: "判断它和你的长期领域目标是否有实际关系。",
    timebox: "按 30/60/90 分钟选择深度，不要把一次 session 做成开放式阅读。",
    primary_material: "Day 4 会接入真实/public source，并在后续支持用户自定义来源。",
    candidate_material: "候选材料用于对照，不要求今天完整处理。",
    criteria: "完成标准用于决定是否可以写入 History。",
  };
  return guidance[detailId] || "围绕该条目和 Agent 讨论下一步。";
}

function openWorkspace() {
  renderWorkspace();
  showView("workspaceView");
}

async function loadToday() {
  setStatus("Connecting");
  try {
    const date = sessionDateForMode();
    state.session = await api(`/sessions/today?date=${date}`);
    setStatus("API OK", true);
    $("demoDateLabel").textContent = state.session.date;
    $("apiBaseLabel").textContent = API_BASE.replace(/^https?:\/\//, "");
    renderTodayCard(state.session);
    renderWorkspace();
  } catch (error) {
    setStatus("Demo Mode");
    $("todayCard").className = "task-card muted";
    $("todayCard").innerHTML = `
      <strong>后端未连接</strong>
      <p>当前 API：<code>${API_BASE}</code></p>
      <p class="error">${error.message}</p>
    `;
  }
}

async function loadHistory() {
  try {
    const checkins = await api("/checkins");
    if (!checkins.length) {
      $("historyList").textContent = "暂无打卡记录。";
      $("historyList").classList.add("muted");
      return;
    }
    $("historyList").classList.remove("muted");
    $("historyList").innerHTML = checkins
      .map(
        (item) => `
          <button class="history-item" type="button">
            <div>
              <span class="tag">${labelTask(item.task_type)}</span>
              <strong>${item.status} · ${item.duration_min} min</strong>
            </div>
            <p>${cleanDisplayText(item.summary)}</p>
            <small>${cleanDisplayText(item.key_insight || "")}</small>
            <small>${cleanDisplayText(item.next_action || "")}</small>
          </button>
        `
      )
      .join("");
  } catch (error) {
    $("historyList").innerHTML = `<span class="error">${error.message}</span>`;
  }
}

async function completeCurrentSession(submitButton = null) {
  if (!state.session || state.isSubmitting) return;
  state.isSubmitting = true;
  if (submitButton) {
    submitButton.disabled = true;
    submitButton.textContent = "正在写入...";
  }

  const payload = {
    duration_min: 30,
    status: "completed",
    summary: $("summary").value,
    key_insight: $("keyInsight").value,
    next_action: $("nextAction").value,
  };

  try {
    const result = await api(`/sessions/${state.session.id}/completion/confirm`, {
      method: "POST",
      body: JSON.stringify(payload),
    });
    state.session = result.session;
    renderTodayCard(state.session);
    renderWorkspace();
    await loadHistory();
    showView("historyView");
  } catch (error) {
    $("workspace").innerHTML = `<span class="error">${error.message}</span>`;
  } finally {
    state.isSubmitting = false;
    if (submitButton) {
      submitButton.disabled = false;
      submitButton.textContent = "完成并写入 History";
    }
  }
}

document.querySelectorAll("[data-mode]").forEach((button) => {
  button.addEventListener("click", async () => {
    state.mode = button.dataset.mode;
    document.querySelectorAll("[data-mode]").forEach((item) => item.classList.remove("active"));
    button.classList.add("active");
    $("manualPicker").classList.toggle("hidden", state.mode !== "manual");
    await loadToday();
  });
});

document.querySelectorAll("[data-tab]").forEach((button) => {
  button.addEventListener("click", async () => {
    showView(button.dataset.tab);
    if (button.dataset.tab === "historyView") await loadHistory();
  });
});

$("refreshToday").addEventListener("click", () => loadToday());
$("refreshHistory").addEventListener("click", () => loadHistory());
$("backToday").addEventListener("click", () => showView("todayView"));
$("backWorkspace").addEventListener("click", () => showView("workspaceView"));
$("checkinForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  await completeCurrentSession(event.submitter);
});

renderManualPicker();
if (state.mode === "manual") {
  document.querySelectorAll("[data-mode]").forEach((item) => item.classList.remove("active"));
  document.querySelector('[data-mode="manual"]').classList.add("active");
  $("manualPicker").classList.remove("hidden");
}
loadToday()
  .then(loadHistory)
  .then(async () => {
    if (AUTO_COMPLETE) await completeCurrentSession();
  });
