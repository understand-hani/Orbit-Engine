# GOAI Project Memory

Last updated: 2026-08-03

This file is written for future Codex sessions so the GOAI competition work can resume without rediscovering context.

## 1. Working Directory

Competition workspace:

```text
/home/maxh/Agent/GOAI
```

Original personal Infra Agent project:

```text
/home/maxh/Agent/infra
```

Decision:

- Do not continue managing the competition product as only an infra branch.
- Treat `/home/maxh/Agent/GOAI` as the independent competition workspace.
- Reuse useful architecture/code/docs from infra, but the competition product is not identical to the personal iOS app.

## 2. Handbook Files

Relevant GOAI handbook PDFs already exist in the workspace:

```text
/home/maxh/Agent/GOAI/Boundless Agents.pdf
/home/maxh/Agent/GOAI/Agent Infra.pdf
```

Track decision after reading both handbooks:

```text
Primary track: Boundless Agents
Recommended topic: AI + Education / Vocational Education
Do not prioritize Agent Infra for this deadline.
```

Reason:

- Boundless Agents emphasizes real user scenarios, at least one demonstrable closed-loop task, product experience, runnable demo, and traceable data/compliance.
- Agent Infra has harder requirements around AgentTeams, at least three agents, mandatory Skill engineering, enterprise-level scenarios, approval/rollback/audit, and verifiable multi-agent infrastructure.
- The current product is much closer to Boundless Agents than Agent Infra.

## 3. Product Direction

Competition product should not be described as only the user's personal career app.

Current product abstraction:

```text
圆周引擎 / Orbit Engine
```

Product category:

```text
Mobile-first web Agent for recurring field exploration and vocational capability building.
```

Core idea:

```text
Users define a long-term field and a recurring weekly rhythm.
Each day, the Agent opens a structured session, prepares materials or context,
guides a small task, records check-ins, supports discussion, and preserves history
for the next cycle.
```

The user's personal AI/autonomous-driving career Infra Agent is one field template, not the whole generic product.

## 4. Session Type Decisions

Earlier abstract session names such as `Action`, `Reflection`, and `Decision` felt too vague.

Current preferred session types:

```text
Radar
  Discover external signals: papers, trends, products, news, repos, opportunities.

Deep Dive
  Process one material deeply: paper, repo, article, course, case, report.

Opportunity Alignment
  Align learning with external requirements: JD, competition, project opportunity,
  market demand, user feedback. In the user's personal career template, JD is one data source here.

Weekly Studio
  End-of-week workspace for archive, review, ability-profile update, next-week plan,
  resume/portfolio updates when relevant.
```

For the 8/16 submission, do not implement everything. The demo can focus on:

```text
Radar / public source discovery
  -> Deep Dive workspace
  -> Check-in
  -> History
```

Weekly Studio can be shown in product narrative or a lightweight page if time allows.

## 5. Platform Decision

Do not use iOS native as the main competition delivery path.

Reason:

- User does not have a Mac.
- Appetize development/debug loop is too slow for the remaining 13-day window.
- Boundless Agents accepts natural product forms including Web/mobile/browser experiences.

Competition delivery should be:

```text
Mobile-first Web / PWA-ready Web App
  -> FastAPI backend
```

Important:

- It must work on phone browser.
- It should be responsive at mobile width.
- Demo video should show a phone-like vertical flow.
- Submission materials should explicitly say it is mobile-first web, not desktop-only.

## 6. Submission Materials Needed Before 2026-08-16

Mandatory:

- Project Introduction within 500 words.
- Proposal PPT/PDF.

Strongly recommended:

- 60-90 second demo video or GIF.
- Repository or runnable package with README.
- Data and compliance notes.

Initial round does not require runnable code, but the handbook warns against concept-only or static marketing materials. A verifiable prototype/video is important.

## 7. Current GOAI Files Created

Copied from infra:

```text
/home/maxh/Agent/GOAI/docs/competition_product_definition.md
/home/maxh/Agent/GOAI/docs/competition_execution_plan.md
```

Generated in GOAI:

```text
/home/maxh/Agent/GOAI/memory/PROJECT_MEMORY.md
/home/maxh/Agent/GOAI/submission/product_positioning.md
/home/maxh/Agent/GOAI/submission/demo_script.md
```

## 8. Next Work Recommendation

Do top-level definition first, then build.

Recommended next implementation direction:

```text
Create a minimal mobile-first Web demo.
Use current FastAPI APIs where possible.
Add only the smallest backend changes needed for:
  - research session generation
  - public paper/arXiv source
  - check-in -> session status
  - history restore
```

Avoid spending critical time on:

- Native iOS.
- Appetize-first iteration.
- Full JD Intelligence polish.
- PDF annotation persistence.
- Multi-user auth.
- Agent Infra/AgentTeams migration.


## 9. Code Migration

On 2026-08-03, the reusable code from `/home/maxh/Agent/infra` was copied into `/home/maxh/Agent/GOAI`:

```text
/home/maxh/Agent/GOAI/backend
/home/maxh/Agent/GOAI/ios
```

Copy strategy:

- Used `rsync`.
- Excluded `backend/.env`.
- Excluded Python caches.
- Excluded virtual environments.
- Excluded local data/database files.
- Excluded packaged app zip.

Current interpretation:

- `backend/` is the actual reusable FastAPI backend base.
- `ios/` is preserved as the original SwiftUI prototype and long-term personal app reference.
- The competition implementation still needs a new mobile-first web frontend under `web/`.

Do not prioritize iOS build or Appetize iteration before the 8/16 submission. The competition demo should be mobile browser / responsive web.

## 10. Operating Rule For Future Sessions

When working on the GOAI project, future Codex sessions must treat the plan document as the active project tracker:

```text
/home/maxh/Agent/GOAI/docs/13_day_competition_plan.md
```

After completing any GOAI task, update that document before final response:

- mark the corresponding checklist item
- update any changed status
- add a dated note under `Progress Log`

This is a user requirement, not an optional documentation preference.

## 11. Schedule Compression Decision

On 2026-08-03, user decided to compress the original Day 2 and Day 3 work into one day.

Reason:

- Feature implementation is the real critical path.
- The project needs to save time for later demo, materials, video, and polish.
- Backend changes should reach a debuggable state quickly.

Updated near-term target:

```text
In one day:
  -> audit and adjust backend closed-loop APIs
  -> reach a debuggable backend state
  -> create the minimal mobile-first web shell if possible
```

Priority inside that compressed day:

1. Backend can run from `/home/maxh/Agent/GOAI/backend`.
2. Demo-critical APIs are verified or minimally fixed.
3. Check-in/session/history path is debuggable.
4. Minimal `web/` shell exists only after backend flow is clear.

Do not spend that day on iOS, JD polish, PPT, or UI decoration.

## 12. Superseded Rebalanced 13-Day Plan Principle

Superseded by Section 13 below.

On 2026-08-03, user noticed the plan had duplicated Day 5 and Day 6 work around Research Workspace quality.

The plan was corrected in:

```text
/home/maxh/Agent/GOAI/docs/13_day_competition_plan.md
```

Previous priority after Day 2:

```text
Day 3: mock end-to-end loop
Day 4: closed-loop state + mobile debugging
Day 5: public paper source
Day 6: Agent-guided session quality
Day 7: stabilization, smoke tests, runbook
Day 8: demo content freeze + screenshots
Day 9: submission text materials
Day 10: proposal PPT/PDF draft
Day 11: video dry run + final bugfix window
Day 12: final demo video + materials freeze
Day 13: submission freeze
```

Previous principle:

- Functionality first.
- One complete loop is more important than broad feature coverage.
- Day 5 is data/source credibility.
- Day 6 is product/session quality, not another data-source day.
- Submission materials start only after the demo path is stable enough to describe truthfully.

This was later corrected again because the product needs one dedicated debug day for each of the four core session types.

## 13. Superseded Product Name And Four-Session Debug Schedule

Superseded by Section 14 below for implementation scope.

On 2026-08-03, user clarified that the competition product needs to prove all four core session abstractions, not only one Research Feeder loop.

Product name decision:

```text
中文名: 圆周引擎
English name: Orbit Engine
```

Reason:

- `圆周引擎` captures recurring exploration, action, review, and next-cycle continuation.
- `Orbit Engine` is preferred over the literal `Cycle Engine` because it is more memorable as a product name while still expressing rhythm and recurrence.

Core session types:

```text
Radar
Deep Dive
Weekly Studio
Opportunity Alignment
```

Previous schedule adjustment:

- Each of the four core session types gets one dedicated debug day.
- Scheduled Mode / Manual Mode must be implemented and shown.
- Day 3 and Day 4 are compressed into one mock-loop/mobile-debugging day.
- Submission text materials do not need a full separate day; they move into Day 13 finalization.
- The proposal deck must include an independent `reusable architecture / domain mapping table` page.

Important PPT page:

```text
Domain mapping table:
Career capability building
Research direction exploration
Creator / visual IP operation
Startup / product exploration
Language learning

Each maps to:
Radar source
Deep Dive material
Opportunity Alignment source
Weekly Studio output
```

This domain mapping table is one of the strongest differentiators and must not be reduced to a minor bullet under reusable value.

Later correction:

- Product name remains `圆周引擎 / Orbit Engine`.
- Four session abstractions remain important for product story and reusable architecture.
- But implementation before 8/16 should not make all four full end-to-end workflows.
- Only Deep Dive is the required deep runnable closed loop; Radar, Weekly Studio, and Opportunity Alignment are lightweight template/domain-mapping proof unless time remains.

## 14. Handbook-Based Scope Correction

On 2026-08-03, user brought Claude's critique that the plan had drifted from "narrow and deep" back to "broad and shallow" by trying to make Radar, Deep Dive, Weekly Studio, and Opportunity Alignment all end-to-end workflows.

This critique is accepted.

Handbook basis:

- Boundless Agents Section 8.1 requires entries to address real scenarios, reflect Agent capabilities, and form a closed-loop task.
- Section 8.2 defines the closed loop: task input, intent understanding, task planning, capability invocation, result delivery, validation/feedback, and safety boundaries.
- Section 10 gives 25% to Agent Capabilities and Task Closed-Loop, 20% to Product Experience and Demo Completeness, and 15% to Technical Implementation Depth.

Interpretation:

```text
The competition rewards at least one deep, verifiable task chain more than several shallow feature paths.
```

Updated implementation scope:

```text
Deep runnable chain before 8/16:
Today -> Scheduled/Manual Deep Dive -> public paper source or fallback
-> Agent-guided Deep Dive -> check-in -> History.
```

Lightweight proof only before 8/16:

```text
Radar
Weekly Studio
Opportunity Alignment
```

These should be shown as reusable session templates and domain-mapping examples, not implemented as full backend/frontend/check-in/history workflows unless the main Deep Dive loop is already stable.

Important:

- Full JD Intelligence remains cut from 8/16 scope.
- JD is only one Opportunity Alignment example.
- Proposal/video should keep the recorded demo narrow: Deep Dive closed loop.
- PPT should still include a strong domain mapping table to prove reuse across fields.

## 15. Day 5 / Day 6 Scope Adjustment

On 2026-08-03, user clarified the balance between "narrow and deep" and "not leaving the other three session types empty."

Updated interpretation:

```text
Deep Dive remains the only full runnable closed loop before 8/16.
Radar, Weekly Studio, and Opportunity Alignment should still have visible lightweight functionality.
They should not be only PPT concepts.
```

Plan adjustment:

```text
Day 5:
  Lightweight Radar / Weekly Studio / Opportunity Alignment.
  Goal: visible previews / lightweight workflows / sample cards in one compressed day.

Day 6:
  Closed-loop evidence + Scheduled/Manual Mode.
  Goal: merge original check-in/history/session-status work with scheduled/manual interaction model.
```

Important boundaries:

- Do not implement full JD Intelligence.
- Do not make Radar / Weekly Studio / Opportunity Alignment full backend/frontend/check-in/history workflows unless the Deep Dive chain is already stable.
- Do make each of the three non-main session types visible and understandable in the UI.

## 16. Day 2 Implementation Status

On 2026-08-03, Day 2 work started and reached a debuggable backend + minimal web shell state.

Completed:

- Created `/home/maxh/Agent/GOAI/backend/venv` with `virtualenv`.
- Installed `backend/requirements.txt`.
- Confirmed the FastAPI app imports successfully.
- Ran local uvicorn HTTP smoke in non-sandbox network mode:
  - `GET /api/health` -> 200
  - `GET /api/today` -> 200
  - `GET /api/sessions/today` -> 200
  - `GET /api/sessions/mock` -> 200
  - `GET /api/checkins` -> 200
- Confirmed service-level completion loop:
  - `FeedService.get_or_create_mock_session`
  - `CheckinService.confirm_completion`
  - session status becomes `completed`
  - check-in status becomes `completed`
  - `list_checkins` returns the new check-in
- Added CORS middleware in `backend/app/main.py` so static/mobile web can fetch FastAPI during local demo.
- Created the mobile-first web shell:
  - `/home/maxh/Agent/GOAI/web/index.html`
  - `/home/maxh/Agent/GOAI/web/app.js`
  - `/home/maxh/Agent/GOAI/web/style.css`
- Created `/home/maxh/Agent/GOAI/docs/backend_api_demo_flow.md`.

Critical API conclusion:

```text
Use POST /api/sessions/{session_id}/completion/confirm for the demo check-in.
Do not use POST /api/checkins as the main demo action, because it saves a check-in but does not update session status.
```

Current limitation:

- Browser-level interaction of the new web shell has not yet been visually verified.
- The current date, 2026-08-03, is a Monday, so `/api/sessions/today` returns a `tech_radar` scheduled session by default. Day 3 should decide whether to use a date override, a manual Deep Dive selector, or a small backend endpoint so the recorded demo reliably starts with Deep Dive.
- `pytest` is not in backend requirements; Day 2 verification used route status smoke plus a service-level script.

Recommended next step:

```text
Day 3:
Run backend normally, open web/index.html in a browser/mobile viewport,
then make Today -> Deep Dive Workspace -> completion confirm -> History work visibly.
```

## 17. Day 3 Implementation Status

On 2026-08-04, Day 3 mock loop and mobile debugging were completed.

Main result:

```text
The mobile web demo can now run:
Today -> Deep Dive Workspace -> Check-in -> History
with mock backend data and visible completion evidence.
```

Important implementation decisions:

- The web demo defaults to fixed date `2026-08-06`.
- Reason: `2026-08-06` is a Thursday and maps to `research_feeder / Deep Dive` in the existing `WeeklyCoordinator`.
- This prevents the demo from switching to Radar/JD just because the real date changes.
- The frontend supports URL overrides:
  - `?api=http://127.0.0.1:8019/api`
  - `?date=2026-08-06`
  - `?auto=1`
- `auto=1` is only for browser/headless verification; normal demo recording should omit it.

Files changed or added:

```text
/home/maxh/Agent/GOAI/web/index.html
/home/maxh/Agent/GOAI/web/app.js
/home/maxh/Agent/GOAI/web/style.css
/home/maxh/Agent/GOAI/docs/demo_click_path.md
/home/maxh/Agent/GOAI/docs/day3_mobile_375.png
/home/maxh/Agent/GOAI/docs/day3_mobile_390.png
/home/maxh/Agent/GOAI/docs/day3_mobile_430.png
```

Verified:

- `node --check /home/maxh/Agent/GOAI/web/app.js` passed.
- Backend service-level Deep Dive session for `2026-08-06` returns:
  - `session_2026-08-06_research_feeder`
  - `task_type=research_feeder`
  - `session_mode=scheduled`
  - `suggested_action=open_paper_reader`
- Chromium headless DOM verification with local static server and FastAPI passed:
  - `API OK`
  - `研究阅读启动`
  - `completed`
  - `闭环完成`
  - `Check-in saved`
  - `History refreshed`
  - History contains the check-in summary.
- Mobile screenshots were generated at 375px, 390px, and 430px widths.

Next recommended step:

```text
Day 4:
Replace the Deep Dive mock source with a real/public source path, preferably arXiv,
while keeping the existing closed-loop Web flow stable.
```

Day 3 follow-up:

- User reported that the pushed card felt unclickable.
- Fixed the Today card so the whole card opens the Workspace, not only the inner `打开 Workspace` button.
- Added a mobile tap hint.
- `node --check /home/maxh/Agent/GOAI/web/app.js` passed after the fix.

Day 3 iPhone preview follow-up:

- User reported that refreshing on iPhone showed `Demo Mode`.
- Root cause: frontend default API base used `127.0.0.1`, which points to the iPhone itself after refresh/opening a bare URL.
- Fixed `web/app.js` so the default API base follows `window.location.hostname` and uses port `8020`.
- Now `http://172.20.10.4:8090/` can work without long query parameters as long as backend runs on `172.20.10.4:8020`.
- Verified with Chromium against bare URL `http://172.20.10.4:8090/`: DOM contained `API OK`, `Deep Dive`, and `研究阅读启动`.

Stronger iPhone preview fix:

- FastAPI now serves the web demo directly:
  - `GET /demo` -> `web/index.html`
  - static assets are mounted from `/home/maxh/Agent/GOAI/web`
- Preferred iPhone URL is now:

```text
http://172.20.10.4:8020/demo
```

- This avoids cross-port access from `8090` to `8020`.
- `index.html` now cache-busts CSS/JS with `?v=20260804b`.
- `web/app.js` ignores stale `localStorage.orbit_api_base` values that point to `127.0.0.1` or `localhost` when the page is opened from a LAN IP.
- Verified with Chromium against `http://172.20.10.4:8020/demo`: DOM contained `API OK`, `Deep Dive`, and `研究阅读启动`.

Second iPhone / interaction follow-up:

- User reported that tapping the `刷新` button still changed the page into `Demo Mode`.
- Root cause: `refreshToday` had two event handlers; one old handler passed the click event object directly into `loadToday(path)`, so the frontend tried to fetch an invalid path.
- Removed the bad direct handler and kept `() => loadToday()`.
- Cache version bumped to `?v=20260804c`.
- User also objected that the Web UI had become a one-page stacked flow unlike the existing iOS interaction model.
- This criticism is accepted. Backend was reused, but the competition Web frontend was a new thin shell and had drifted from the iOS product interaction.
- First correction completed:
  - Home view: Today card, Scheduled/Manual mode, History
  - Workspace detail view: opened by tapping the Today card or `打开 Workspace`
  - Back button returns to Home
- Verified with Chromium against `http://172.20.10.4:8020/demo`: DOM contained `API OK`, `homeView`, `workspaceView`, `点击卡片进入详情页`, and `研究阅读启动`.

Important product direction:

```text
The competition Web demo should follow the existing iOS interaction logic:
Today/Home card -> type-specific workspace detail -> check-in/history,
not a single long webpage with every section visible at once.
```

Third interaction follow-up:

- User clarified the desired competition Web structure:
  - bottom tab bar, consistent with the iOS app
  - no standalone JD tab in competition Web
  - tabs should be `今日 / 历史 / 设置`
  - Today should be clean, not a long scroll page
  - Scheduled/Manual selector should be at the top of Today
  - Scheduled is default
  - Manual reveals session-type choices
  - selecting Manual types should update the Today task card
  - tapping the task card opens the specific workspace
- Implemented this structure in Web:
  - `todayView`
  - `workspaceView`
  - `historyView`
  - `settingsView`
  - bottom `tabbar`
- Removed user-facing `Loop Evidence`; it was only a debug/proof widget and should not be part of the product UI.
- Workspace now shows tappable detail cards for Reading Pack, Reading Goal, Why Selected, 30/60/90 path, and Completion Criteria.
- Manual choices currently map to existing backend dates:
  - Radar -> `2026-08-04`
  - Deep Dive -> `2026-08-06`
  - Alignment -> `2026-08-05`
- Generated updated screenshot:

```text
/home/maxh/Agent/GOAI/docs/day3_tabbed_today_390.png
```

AI/API status clarification:

- No real AI API has been connected yet for the competition Web demo.
- Current backend still runs in mock mode unless `.env` changes `LLM_PROVIDER`.
- Existing backend has OpenRouter support mostly for JD Intelligence, but competition priority is not to expose full JD workflow.
- Day 4 should focus on real/public source integration for Deep Dive, preferably arXiv.
- Lightweight LLM API integration can be added after the source path if it improves Agent guidance, but it should not disrupt the closed-loop demo.

Manual session mapping decision:

```text
Radar
  -> existing tech_radar / TechRadarView / tech-radar-feeder concept

Deep Dive
  -> existing research_feeder / ResearchReaderView

Opportunity Alignment
  -> existing jd_analysis / JDIntelligenceView capability, renamed in product UI

Weekly Studio
  -> reuse existing Sunday review / catch-up research_feeder behavior for now
  -> do not add backend enum before 8/16 unless required
```

User-facing naming rule:

- Use competition product names in Web UI.
- Old names like JD are correspondence labels only and should not define the product boundary.
- Avoid exposing the user's personal research direction terms in generic product UI.
- Product content should eventually be configured by each user.

Future onboarding/configuration requirement:

- Add a first-use flow later, not in the current mapping task.
- The flow should ask:
  - what the user's goal is, such as transition, job change, exam, college entrance, civil service exam, broad exploration, or casual learning
  - what field/direction they want to learn, research, or explore
  - which real-world information sources should be tracked, such as opportunities, competitions, schools, mentors, papers, communities, policies, or role requirements
  - what weekly rhythm and manual override preference they want
- This should be added to the later product/reusability work, currently Day 7.

Fourth interaction follow-up:

- User explicitly clarified that the Web frontend should first migrate the existing `/home/maxh/Agent/infra` iOS frontend interaction style, not invent a new Web UI and then optimize it.
- Concrete reference:

```text
/home/maxh/Agent/infra/2026-08-04 15-10-30屏幕截图.png
```

- Important interpretation:
  - Web should follow iOS List/Form/Section/NavigationLink semantics.
  - Workspace rows should be tappable and lead to deeper detail views.
  - Radar / JD-Alignment / Paper-Deep-Dive should inherit their original iOS workspace structure as much as possible.
  - Competition changes should be product-scope changes, not a wholesale frontend interaction redesign.
- Implemented additional migration:
  - Deep Dive workspace now mirrors `ResearchReaderView`: `目标 / 计划 / 论文 / 完成标准`.
  - Radar workspace mirrors `TechRadarView`: `信号 / Agent 讨论`.
  - Alignment workspace mirrors `JDIntelligenceView`: `概览 / 工作区 / Agent 讨论`.
  - Rows use iOS-like list row styling with right chevrons and open a detail view.
  - `Loop Evidence` remains removed from user-facing UI.
- Generated updated screenshot:

```text
/home/maxh/Agent/GOAI/docs/day3_ios_style_migration_390.png
```

Fifth mapping / migration follow-up:

- User confirmed:
  - Weekly Studio should use option C: reuse existing Sunday review / `research_feeder`.
  - Use new competition product names in UI.
  - Existing old names are correspondence labels only.
  - Structure-first migration with mock data is acceptable.
  - Generic product UI must avoid the user's personal research-direction terms.
- Implemented:
  - Manual has four entries:
    - Radar
    - Deep Dive
    - Opportunity Alignment
    - Weekly Studio
  - Mapping:
    - Radar -> `tech_radar`
    - Deep Dive -> `research_feeder`
    - Opportunity Alignment -> `jd_analysis`
    - Weekly Studio -> Sunday review / `research_feeder`
  - Weekly Studio is rendered according to manual selection before falling back to backend task type, so it does not appear as Deep Dive.
  - User-facing Web text now prefers generic terms such as `materials`, `opportunities`, `sources`, `ability profile`, and `weekly rhythm`.
  - History rendering sanitizes earlier demo text such as `论文源` and `调试闭环` into generic product language.
  - Workspace rows now open detail pages, closer to iOS `NavigationLink`.
- Generated screenshot:

```text
/home/maxh/Agent/GOAI/docs/day3_four_session_mapping_390.png
```

Sixth Opportunity Alignment migration follow-up:

- User correctly reported that opening Opportunity Alignment still felt unchanged and did not match the previous iOS interaction.
- Root issue: only the first-level workspace rows had been migrated; row details all used a generic demo preview.
- Implemented deeper iOS-style hierarchy for Opportunity Alignment:
  - Add opportunity, mapped from `JDAddOptionsView` / `JDEntryFormView`
  - Opportunity library, mapped from `JDLibraryView`
  - Opportunity entry detail, mapped from `JDEntryDetailView`
  - Candidate actions, folders, and action detail, mapped from `CandidateActionsView`
  - Skill profile, mapped from `SkillStackView`
  - Task state and Period, mapped from `TaskStateView`
  - Agent discussion, mapped from `AgentChatView`
- Kept competition product wording generic:
  - opportunity
  - external requirements
  - ability profile
  - candidate actions
  - task state
- Verified `http://172.20.10.4:8020/demo?manual=alignment` with Chromium DOM:
  - `API OK`
  - `Opportunity Alignment`
  - `机会库`
  - `候选行动`
  - `能力画像`
  - `任务状态`
  - `Agent 讨论`
  - no `JD`
  - no `Demo Mode`

Dedicated polish day decision:

- User requested a dedicated later day for interaction logic optimization and visual polish.
- Plan changed so Day 9 is now:

```text
Interaction Logic And iOS-Style Polish
```

- Purpose:
  - align Web more closely with the original iOS interaction model
  - clean Today / Manual / Workspace / History / Settings
  - remove dead cards and debug widgets
  - make the iPhone recording feel like a coherent mobile app
- The old Day 9 screenshot-freeze work is moved into Day 11 dry-run/screenshot refresh.

Fourth UI follow-up:

- User said the interface still felt low-quality and asked for an iOS feel.
- Updated CSS/HTML toward iOS system visual language:
  - `#f2f2f7` system-style background
  - large title typography
  - iOS-style segmented control
  - grouped rounded task card
  - translucent bottom tab bar
  - CSS-drawn tab icons for Today / History / Settings
  - cache version bumped to `20260804e`
- Generated screenshot:

```text
/home/maxh/Agent/GOAI/docs/day3_ios_style_today_390.png
```

Current interpretation:

```text
The Web demo should not look like a generic webpage.
It should behave and visually read as an iPhone-first mobile app shell, while remaining fast static Web + FastAPI for the 8/16 deadline.
```

Plan document language update:

- On 2026-08-04, `docs/13_day_competition_plan.md` was converted into the active Chinese version.
- Future GOAI sessions should treat this Chinese plan as the primary tracker.
- Keep necessary English identifiers as-is when useful:
  - `Orbit Engine`
  - `Radar`
  - `Deep Dive`
  - `Weekly Studio`
  - `Opportunity Alignment`
  - API paths, filenames, screenshots, and implementation identifiers.
- After completing GOAI tasks, continue updating the Chinese checklist and `进度记录` section in `docs/13_day_competition_plan.md`.

Calendar mapping:

- For the 13-day GOAI competition plan, 2026-08-04 is Day 1.
- The plan runs through 2026-08-16 as Day 13, matching the submission deadline.
- `docs/13_day_competition_plan.md` headings now include both day number and date.
