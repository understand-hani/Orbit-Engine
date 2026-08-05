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
  userContext: null,
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
  const digest = payload.digest;
  const display = displaySession();

  $("detailType").textContent = display.typeLabel;
  $("detailTitle").textContent = display.title;

  if (state.mode === "manual" && state.manualSelection === "weekly_studio") {
    renderSessionQueue("Weekly Studio", "复盘、归档、调整下周节奏。", "weekly_detail", "新建 Weekly Studio");
    return;
  }

  if (session.task_type === "tech_radar") {
    renderSessionQueue("Radar", digest?.summary || "发现外部信号、趋势和可行动线索。", "radar_detail", "新建 Radar");
    return;
  }

  if (session.task_type === "jd_analysis") {
    renderSessionQueue("Opportunity Alignment", "把学习与外部机会、评价标准和现实需求对齐。", "alignment_detail", "新建 Alignment");
    return;
  }

  renderDeepDiveQueue(session);
}

function renderSessionQueue(title, subtitle, detailId, createLabel) {
  $("workspace").className = "ios-list";
  $("workspace").innerHTML = `
    ${sectionIntro(title, subtitle)}
    ${sectionHeader("当前")}
    ${actionCard(title, "active · 点击进入当前工作区", detailId)}
    ${sectionHeader("开始")}
    ${actionCard(createLabel, "选择信息源并生成新的 session。", "source_select")}
  `;
  bindDetailRows();
}

function renderDeepDiveQueue(session) {
  const payload = session.payload || {};
  const materials = payload.materials || [];
  const primary = materials.find((item) => item.id === payload.primary_material_id) || materials[0];
  $("workspace").className = "ios-list";
  $("workspace").innerHTML = `
    ${sectionIntro("Deep Dive", "先选择继续一个未完成的 Deep Dive，或用 PDF、URL、手动材料卡新建。")}
    ${sectionHeader("进行中 / 未完成")}
    ${actionCard(primary?.title || "当前 Deep Dive", `${session.status} · ${primary?.source_type || "material"} · 点击进入`, "deep_dive_detail")}
    ${sectionHeader("新建")}
    ${actionCard("新建 Deep Dive", "选择 PDF、URL 或手动材料卡开始。", "source_select")}
  `;
  bindDetailRows();
}

function actionCard(title, subtitle, detailId) {
  return `
    <button class="action-card" type="button" data-detail="${detailId}" data-title="${title}" data-subtitle="${subtitle}">
      <div>
        <strong>${title}</strong>
        <small>${subtitle}</small>
      </div>
      <span>›</span>
    </button>
  `;
}

function renderResearchWorkspace(session, criteria) {
  $("workspace").className = "ios-list";
  $("workspace").innerHTML = researchWorkspaceContent(session, criteria);
  bindDetailRows();
}

function researchWorkspaceContent(session, criteria) {
  const payload = session.payload || {};
  const materials = payload.materials || [];
  const primary = materials.find((item) => item.id === payload.primary_material_id) || materials[0];
  const recommendation = payload.recommendation_context || {};
  const activePlan = payload.active_plan || state.userContext?.plan;
  const preferences = payload.user_preferences || state.userContext?.preferences;
  return `
    ${sectionIntro("Deep Dive", "深入处理一份材料，形成输入输出、核心证据、方向判断和下一步行动。")}
    ${sectionHeader("目标")}
    ${infoBlock("当前任务", activePlan?.next_action || "选择一份主材料，并围绕一个具体问题完成深入处理。")}
    ${infoBlock("阅读目标", "明确材料的输入、输出、核心方法、证据、局限和是否值得继续。")}
    ${sectionHeader("计划")}
    ${infoBlock("选择理由", recommendation.why_this_material_now || "根据用户定义的长期目标、当前阶段和外部现实信号选择材料。")}
    ${infoBlock("30 / 60 / 90 分钟路径", `${preferences?.session_time_budget_min || 30} 分钟优先形成可记录输出；时间更多时再扩展阅读深度。`)}
    ${sectionHeader("材料")}
    ${primary ? materialRow("主材料", primary, "primary_material") : navRow("主材料", "暂无材料，请先在计划或我的中登记材料。", "primary_material")}
    ${sectionHeader("完成标准")}
    ${infoBlock("Completion criteria", criteria.map((item) => item.description).join("；") || "完成精读段落和下一步判断。")}
    <div class="action-grid">
      ${actionCard("Check-in", "填写完成记录并写入历史。", "checkin_form")}
      ${actionCard("Agent Guidance", "让 Agent 帮你整理洞察、下一步和 Check-in 草稿。", "deep_dive_agent")}
    </div>
  `;
}

function materialRow(label, material, detailId) {
  return navRow(label, `${material.source_type} · ${material.title}`, detailId);
}

function infoBlock(title, body) {
  return `
    <div class="info-block">
      <strong>${title}</strong>
      <p>${body}</p>
    </div>
  `;
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
  bindDynamicActions();
  showView("itemDetailView");
}

function bindDynamicActions() {
  document.querySelectorAll("[data-material-form]").forEach((form) => {
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      const formData = new FormData(form);
      const tags = String(formData.get("tags") || "")
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean);
      const payload = {
        title: String(formData.get("title") || "").trim(),
        source_type: form.dataset.sourceType,
        summary: String(formData.get("summary") || "").trim(),
        url: String(formData.get("url") || "").trim() || null,
        file_path: String(formData.get("file_path") || "").trim(),
        tags,
        related_plan: state.userContext?.plan?.weekly_focus || "",
      };
      const material = await api("/user-context/materials", {
        method: "POST",
        body: JSON.stringify(payload),
      });
      await loadUserContext();
      if (state.session?.payload) {
        state.session.payload.materials = [material, ...(state.session.payload.materials || [])];
        state.session.payload.primary_material_id = material.id;
        state.session.payload.recommendation_context = {
          ...(state.session.payload.recommendation_context || {}),
          why_this_material_now: material.why_selected,
        };
      }
      openItemDetail("当前 Deep Dive", "使用新材料继续。", "deep_dive_detail");
    });
  });

  document.querySelectorAll("[data-action='use-agent-draft']").forEach((button) => {
    button.addEventListener("click", () => {
      const summary = $("agentSummary")?.value || "";
      const insight = $("agentInsight")?.value || "";
      const nextAction = $("agentNextAction")?.value || "";
      openItemDetail("Check-in", "Agent 已生成草稿，可继续修改。", "checkin_form");
      $("summary").value = summary;
      $("keyInsight").value = insight;
      $("nextAction").value = nextAction;
    });
  });

  const checkinForm = $("checkinForm");
  if (checkinForm) {
    checkinForm.addEventListener("submit", async (event) => {
      event.preventDefault();
      await completeCurrentSession(event.submitter);
    });
  }
}

function detailContentFor(title, subtitle, detailId) {
  const materialDetail = materialDetailFor(detailId);
  if (materialDetail) return materialDetail;

  const content = {
    deep_dive_detail: deepDiveDetailContent(),
    source_select: sourceSelectContent(),
    source_pdf: materialFormContent("PDF metadata", "pdf", "登记 PDF 文件名或本地路径，后续可接真实上传。"),
    source_url: materialFormContent("URL", "url", "登记网页、公开文档、GitHub README、文章或课程链接。"),
    source_manual: materialFormContent("手动材料卡", "manual", "手动输入标题和摘要，用于用户自己的资料或离线材料。"),
    checkin_form: checkinFormContent(),
    deep_dive_agent: deepDiveAgentContent(),
    radar_detail: `
      ${sectionIntro("Radar", "当前轻量工作区：发现外部信号并判断是否值得进入 Deep Dive 或 Alignment。")}
      ${sectionHeader("Agent 能做什么")}
      ${infoBlock("过滤噪声", "从材料、repo、新闻、产品、比赛等来源中过滤和用户目标无关的信息。")}
      ${infoBlock("转成行动", "把外部信号转成 Deep Dive、Opportunity Alignment 或 Weekly Studio 的下一步。")}
    `,
    alignment_detail: `
      ${sectionIntro("Opportunity Alignment", "当前轻量工作区：把学习计划和外部机会、评价标准、现实需求对齐。")}
      ${sectionHeader("Agent 能做什么")}
      ${infoBlock("抽取标准", "从机会描述中抽取能力要求、证据要求、风险和下一步。")}
      ${infoBlock("反哺计划", "把外部要求转成当前计划里的任务或材料选择依据。")}
    `,
    weekly_detail: `
      ${sectionIntro("Weekly Studio", "当前轻量工作区：归档本周成果，判断继续、暂停或放弃。")}
      ${sectionHeader("Agent 能做什么")}
      ${infoBlock("整理证据", "汇总 check-in、材料、洞察和下一步。")}
      ${infoBlock("调整节奏", "根据完成情况调整下周 scheduled/manual session。")}
    `,
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
    `
  );
}

function deepDiveDetailContent() {
  const criteria = state.session?.completion?.criteria || [];
  return researchWorkspaceContent(state.session, criteria);
}

function sourceSelectContent() {
  return `
    ${sectionIntro("新建 Deep Dive", "选择本次 Deep Dive 使用的材料来源。当前 demo 先保存 metadata，后续可接真实 PDF 上传和网页抓取。")}
    ${sectionHeader("材料来源")}
    ${actionCard("使用 PDF", "登记 PDF 文件名、本地路径或摘要。", "source_pdf")}
    ${actionCard("登记 URL", "使用公开网页、官方文档、GitHub README、文章或课程链接。", "source_url")}
    ${actionCard("手动材料卡", "直接输入标题和摘要。", "source_manual")}
  `;
}

function materialFormContent(title, sourceType, hint) {
  return `
    ${sectionIntro(title, hint)}
    <form class="form-card" data-material-form data-source-type="${sourceType}">
      <label>标题<input name="title" required value="新的 Deep Dive 材料" /></label>
      <label>摘要<textarea name="summary" rows="4" required>这份材料用于推进当前计划，并形成一次可记录的 Deep Dive 输出。</textarea></label>
      <label>URL<input name="url" placeholder="https://..." /></label>
      <label>PDF/本地路径<input name="file_path" placeholder="/path/to/material.pdf" /></label>
      <label>标签<input name="tags" value="Deep Dive, Material" /></label>
      <button class="primary" type="submit">保存并用于本次 Deep Dive</button>
    </form>
  `;
}

function checkinFormContent() {
  return `
    ${sectionIntro("Check-in", "确认本次 Deep Dive 的完成记录。Agent Guidance 可以先帮你生成草稿，再回来修改。")}
    <form id="checkinForm" class="checkin-form">
      <label>
        Summary
        <textarea id="summary" rows="3" required>完成了今天的 Deep Dive 任务闭环。</textarea>
      </label>
      <label>
        Key insight
        <textarea id="keyInsight" rows="2">Agent 的价值不在提醒，而在把材料、任务、证据和下一步组织成闭环。</textarea>
      </label>
      <label>
        Next action
        <input id="nextAction" value="根据本次 Deep Dive 结果更新计划或进入下一次材料处理。" />
      </label>
      <button class="primary" type="submit">完成并写入 History</button>
    </form>
  `;
}

function deepDiveAgentContent() {
  return `
    ${sectionIntro("Agent Guidance", "Agent 在这里不是聊天装饰，而是把材料、计划和完成标准组织成可提交的 Check-in 草稿。")}
    ${sectionHeader("Agent 判断")}
    ${infoBlock("为什么读这份材料", state.session?.payload?.recommendation_context?.why_this_material_now || "它和当前计划、本周重点或材料偏好相关。")}
    ${infoBlock("建议输出", "本次只需要形成：材料输入/输出、一条关键证据、一个方向判断、一个下一步。")}
    ${sectionHeader("Check-in 草稿")}
    <div class="form-card">
      <label>Summary<textarea id="agentSummary" rows="3">围绕主材料完成了一次 Deep Dive，明确了它和当前计划的关系。</textarea></label>
      <label>Key insight<textarea id="agentInsight" rows="3">这份材料的价值在于把当前计划中的下一步具体化，避免开放式阅读。</textarea></label>
      <label>Next action<input id="agentNextAction" value="把本次洞察写入 History，并在 Weekly Studio 中判断继续/追踪/暂停。" /></label>
      <button class="primary" type="button" data-action="use-agent-draft">用这份草稿去 Check-in</button>
    </div>
  `;
}

function materialDetailFor(detailId) {
  const payload = state.session?.payload || {};
  const materials = payload.materials || state.userContext?.materials || [];
  const primary = materials.find((item) => item.id === payload.primary_material_id) || materials[0];
  const candidates = materials.filter((item) => item.id !== primary?.id).slice(0, 2);
  let material = null;
  if (detailId === "primary_material") material = primary;
  if (detailId.startsWith("candidate_material")) {
    const index = Number(detailId.split("_").pop());
    material = candidates[index] || candidates[0];
  }
  if (!material) return "";

  const source = material.url
    ? `<a class="source-link" href="${material.url}" target="_blank" rel="noreferrer">打开来源</a>`
    : `<span class="local-note">${material.file_path || "本地/手动材料卡"}</span>`;
  return `
    ${sectionHeader("材料")}
    ${sectionIntro(material.title, material.summary)}
    <div class="labeled-list">
      <div><span>来源类型</span><strong>${material.source_type}</strong></div>
      <div><span>关联计划</span><strong>${material.related_plan || "当前计划"}</strong></div>
      <div><span>标签</span><strong>${(material.tags || []).join(" / ") || "-"}</strong></div>
      <div><span>来源</span><strong>${source}</strong></div>
    </div>
    ${sectionHeader("为什么现在读")}
    ${sectionIntro("Agent 推荐理由", material.why_selected || "这份材料和当前计划、领域偏好或下一步行动相关。")}
    ${sectionHeader("Deep Dive 输出")}
    ${navRow("输入 / 输出", "这份材料的输入、输出或要解决的问题是什么？", "material_io")}
    ${navRow("核心证据", "它提供了哪些证据、方法、案例或判断依据？", "material_evidence")}
    ${navRow("下一步", "读完后应该继续、追踪、暂停还是转成行动？", "material_next")}
  `;
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

function openWorkspace() {
  renderWorkspace();
  showView("workspaceView");
}

async function loadToday() {
  setStatus("Connecting");
  try {
    if (!state.userContext) await loadUserContext();
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

async function loadUserContext() {
  try {
    state.userContext = await api("/user-context");
    renderPlanView();
    renderMineView();
  } catch (error) {
    state.userContext = fallbackUserContext();
    renderPlanView();
    renderMineView();
  }
}

function fallbackUserContext() {
  return {
    profile: {
      goal: "针对一个自定义方向建立周期性的学习、探索、记录和反馈闭环。",
      background_summary: "本地 demo fallback：后端重启后会从 SQLite 读取真实用户上下文。",
      current_stage: "验证 Deep Dive 主链路。",
    },
    plan: {
      long_term_goal: "把材料、现实信号和个人行动组织成可持续的能力建设系统。",
      weekly_focus: "本周重点是验证 Deep Dive 闭环：选择材料、明确阅读目标、完成打卡、写入历史。",
      active_tasks: ["选择或登记一份材料", "完成一次 Deep Dive", "写入 History"],
      next_action: "选择 PDF、URL 或手动材料卡开始本次 Deep Dive。",
      tracking_keywords: ["material source", "deep dive", "agent guidance"],
    },
    preferences: {
      fields: ["自定义领域", "学习/探索", "能力建设"],
      source_preferences: ["pdf", "url", "manual"],
      session_time_budget_min: 30,
    },
    materials: [
      {
        id: "fallback_material",
        title: "Fallback Deep Dive material",
        source_type: "manual",
        summary: "后端未更新时使用的本地材料卡。重启 FastAPI 后会使用 SQLite 中的用户材料记录。",
        related_plan: "验证 Deep Dive 闭环。",
        tags: ["Fallback", "Deep Dive"],
        why_selected: "它用于保证计划/我的页面在旧后端下也能展示，不把 404 暴露给用户。",
      },
    ],
  };
}

function renderPlanView() {
  const context = state.userContext;
  if (!context) return;
  const plan = context.plan;
  $("planPanel").className = "ios-list";
  $("planPanel").innerHTML = `
    ${sectionHeader("当前目标")}
    ${navRow("长期目标", plan.long_term_goal, "plan_goal")}
    ${navRow("本周重点", plan.weekly_focus, "plan_weekly_focus")}
    ${sectionHeader("任务")}
    ${(plan.active_tasks || []).map((task, index) => navRow(`任务 ${index + 1}`, task, `plan_task_${index}`)).join("")}
    ${sectionHeader("推荐依据")}
    ${navRow("下一步", plan.next_action, "plan_next_action")}
    ${navRow("Tracking keywords", (plan.tracking_keywords || []).join(" / "), "plan_keywords")}
  `;
  bindDetailRows();
}

function renderMineView() {
  const context = state.userContext;
  if (!context) return;
  const profile = context.profile;
  const preferences = context.preferences;
  const materials = context.materials || [];
  $("minePanel").className = "ios-list";
  $("minePanel").innerHTML = `
    ${sectionHeader("个人情况")}
    ${navRow("个人目标", profile.goal, "mine_goal")}
    ${navRow("背景摘要", profile.background_summary, "mine_background")}
    ${navRow("当前阶段", profile.current_stage, "mine_stage")}
    ${sectionHeader("偏好")}
    ${navRow("关注领域", (preferences.fields || []).join(" / "), "mine_fields")}
    ${navRow("材料源偏好", (preferences.source_preferences || []).join(" / "), "mine_sources")}
    ${sectionHeader("材料库")}
    ${materials.map((item, index) => navRow(item.title, `${item.source_type} · ${item.related_plan}`, index === 0 ? "primary_material" : `candidate_material_${index - 1}`)).join("")}
    ${sectionHeader("本地数据")}
    ${sectionIntro("Local only", "比赛 demo 中个人情况、计划、偏好和材料 metadata 存在本地 SQLite。当前不上传真实隐私资料。")}
  `;
  bindDetailRows();
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
    if (button.dataset.tab === "planView" || button.dataset.tab === "mineView") await loadUserContext();
  });
});

$("refreshToday").addEventListener("click", () => loadToday());
$("refreshHistory").addEventListener("click", () => loadHistory());
$("backToday").addEventListener("click", () => showView("todayView"));
$("backWorkspace").addEventListener("click", () => showView("workspaceView"));

renderManualPicker();
if (state.mode === "manual") {
  document.querySelectorAll("[data-mode]").forEach((item) => item.classList.remove("active"));
  document.querySelector('[data-mode="manual"]').classList.add("active");
  $("manualPicker").classList.remove("hidden");
}
loadUserContext()
  .then(loadToday)
  .then(loadHistory)
  .then(async () => {
    if (AUTO_COMPLETE) await completeCurrentSession();
  });
