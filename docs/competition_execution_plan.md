# Competition Execution Plan

Workspace: `/home/maxh/Agent/GOAI`

Deadline assumption: 13 days remaining.

Primary goal:

```text
Deliver a runnable mobile-first Web Boundless Agents demo with four configurable session types and one complete recorded closed loop.
```

## 1. Key Decision

Do not make the iOS app the competition demo surface.

Reason:

- No local Mac.
- Appetize development/debug loop is too slow.
- iOS build risk can consume the remaining schedule.
- Boundless Agents values runnable workflow and product experience, not a specific platform.

Competition surface:

```text
Web demo + FastAPI backend
```

Long-term personal product surface:

```text
iOS app + FastAPI backend
```

These are related but not identical products.

## 2. 13-Day Priority

### P0: Product Definition And Branch

Status:

- Competition branch created: `competition/boundless-research-agent`.
- Product boundary defined in `docs/competition_product_definition.md`.

Next:

- Keep competition work on this branch.
- Keep personal iOS app work out of the critical path.

### P1: Web Demo Shell

Build:

- Vite + React + TypeScript frontend.
- Pages:
  - Today
  - Research Workspace
  - Check-in
  - History
  - About / Demo Notes

Minimum UI:

- Clean desktop-first layout.
- Works in browser without Appetize.
- Shows source links and session state clearly.

### P2: Research Feeder Closed Loop

Backend work:

- Add or reuse endpoint to get/create today research session.
- Add endpoint to generate research session from real source.
- Add session status update.
- Make check-in creation update session status or expose a direct status update call.
- Add History query that returns check-ins and related sessions.

Frontend flow:

```text
Today
  -> Generate Research Session
  -> Open Workspace
  -> Read selected paper cards
  -> Submit check-in
  -> See completed / partial status
  -> Open History
```

Definition of done:

- One browser recording can show the full flow without manual database editing.

### P3: Real Data Source

Recommended source:

```text
arXiv API
```

Why:

- Public.
- Stable enough.
- Easy to disclose.
- Directly fits research feeder.
- Stronger than mock data for judging.

Minimum fields:

- title
- authors
- abstract
- published date
- arXiv URL
- PDF URL
- categories
- query keyword
- fetched_at

Initial queries:

```text
"3D Gaussian Splatting"
"4D Gaussian"
"world model autonomous driving"
"driving video generation"
"autonomous driving simulation"
```

Rule-based selection is acceptable for the first demo.

Fallback:

- If arXiv is unavailable, use built-in demo sample data and show a clear fallback message.

### P4: README And Reproducibility

README must include:

- Project name and selected track/topic.
- One-sentence differentiation.
- Architecture diagram.
- Demo workflow.
- Backend startup.
- Frontend startup.
- Environment variables.
- Data source and compliance notes.
- Known limitations.
- Roadmap.

Do not bury the demo path. Judges should know exactly what to click.

### P5: Demo Video

Target length:

```text
60-90 seconds
```

Script:

1. Open Today.
2. Generate research session from arXiv.
3. Show primary/candidate paper and why selected.
4. Open workspace reading plan.
5. Submit check-in.
6. Open History and show completed session.
7. End with architecture / reusable session runtime screen.

## 3. What Not To Do In This Branch

Do not spend critical time on:

- Appetize-first iOS iteration.
- SwiftUI visual polish.
- JD Intelligence full CRUD.
- Skill stack/task state editor.
- Resume editor.
- PDF annotation persistence.
- Multi-user auth.
- Generic multi-agent infrastructure.
- New travel planning reuse proof.

These are valid long-term features, but not required for Boundless preliminary/semi-final credibility.

## 4. Technical Shape

Recommended repo layout:

```text
backend/
  app/
web/
  package.json
  src/
docs/
```

Backend remains FastAPI.

Frontend should be simple:

- Vite.
- React.
- TypeScript.
- CSS modules or plain CSS.

Avoid heavy UI frameworks unless already installed. The demo needs reliability more than component richness.

## 5. Evaluation Alignment

Boundless scoring map:

```text
Industry Scenario Value 25%
  -> adult vocational capability-building for technical professionals

Agent Capabilities and Task Closed-Loop 25%
  -> task understanding, arXiv source call, reading plan, check-in, History

Product Experience and Demo Completeness 20%
  -> browser demo, clear workflow, stable recording

Technical Implementation Depth 15%
  -> FastAPI session runtime, typed payloads, source adapter, persistence

Safety, Compliance, Traceability 10%
  -> public arXiv data, local/simulated personal data, clear boundaries

Open / Reusable Contribution 5%
  -> reusable session schema, API docs, demo data, README
```

## 6. Today’s Concrete Output

Today should end with:

- Competition branch exists.
- Competition product definition committed or at least written.
- Web-first decision accepted.
- First implementation task selected:
  - create `web/` Vite app, or
  - add backend arXiv source service.

Recommended first implementation task:

```text
Add backend arXiv source service and a research-session generation endpoint.
```

Reason:

- It proves this is not a mock-only UI shell.
- It gives the frontend real data to render.
- It directly supports the demo story.
