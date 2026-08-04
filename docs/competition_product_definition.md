# Competition Product Definition

Working branch: `competition/boundless-research-agent`

Competition track: GOAI Boundless Agents

Recommended topic positioning:

```text
AI + Education / Vocational Education Agent
```

## 1. Product Name

圆周引擎 / Orbit Engine

Alternative names:

- Cycle Engine
- Momentum Agent
- Field Orbit Agent

For submission, prefer `圆周引擎 / Orbit Engine` because it captures the core idea of recurring field exploration and is broader than a research-only name.

## 2. Product Boundary

The competition product is not the full personal Infra Agent iOS app.

It is a focused Web-first demo extracted from the larger personal Infra Agent system:

```text
Personal Infra Agent
  -> broad personal system
  -> iOS-first
  -> Today / JD / Research / Resume / History

圆周引擎 / Orbit Engine
  -> competition product
  -> Web-first
  -> one complete research capability-building loop
  -> Today -> Research workspace -> real paper source -> check-in -> History
```

The competition product should keep the strongest scenario and cut everything that does not help the first demo.

## 3. Target User

Adult technical professionals who need to continuously build frontier technical capability while working full time.

Initial persona:

- Autonomous-driving / AI engineer.
- Has limited high-quality study time.
- Needs to track frontier research, choose useful materials, produce learning evidence, and preserve career optionality.
- Does not need a generic todo app.

## 4. Core Problem

The real problem is not lack of information.

The real problem is activation cost:

```text
Too many papers, repos, JDs, and research directions
  -> hard to decide what to read today
  -> fragmented time causes shallow reading
  -> insights are not preserved
  -> long-term capability evidence is weak
```

The Agent should reduce the cost of starting and completing one useful research task.

## 5. One-Sentence Differentiation

Orbit Engine is not a todo app. It is a vocational capability-building Agent that turns frontier research signals into structured recurring sessions, then preserves check-ins and evidence for long-term growth.

## 6. Competition Demo Loop

The demo should complete one verifiable task chain:

```text
User opens Today
  -> Agent creates today's Research Session
  -> Agent calls arXiv or a public paper source
  -> Agent selects 1 primary paper and 1 candidate paper
  -> Agent explains why each paper matters
  -> User opens Research Workspace
  -> User reads structured input/output/method/evidence prompts
  -> User submits check-in
  -> Backend updates session status
  -> History shows the completed session
```

This maps directly to Boundless Agents requirements:

- Task input: date, focus topics, time budget.
- Intent understanding: research capability-building session.
- Task planning: 30/60/90 minute reading plan.
- Tool invocation: arXiv/public source query.
- Knowledge enhancement: paper metadata and summary.
- Result delivery: structured research workspace.
- Validation and feedback: check-in, session status, History.
- Safety boundary: learning assistance only, not educational credentialing or career decision replacement.

## 7. MVP Scope For 13 Days

Must include:

- Web demo entry.
- Backend session API.
- Research Feeder session.
- arXiv or public paper source integration.
- Research workspace page.
- Check-in submission.
- Session status update.
- History page.
- README with reproducible run instructions.
- 60-90 second demo video.

Should include if time allows:

- One demo mode with stable sample data.
- Simple failure state when arXiv is unavailable.
- Source links and timestamps.
- Exportable check-in summary.

Cut from competition MVP:

- iOS app as primary demo surface.
- JD Intelligence full CRUD polish.
- Resume editor.
- PDF annotation persistence.
- Multi-tab personal app completeness.
- App Store / TestFlight / Appetize-first delivery.

## 8. Product Form Decision

Competition product should be Web-first.

Reason:

- The user does not have a Mac.
- Appetize iteration is too slow for a 13-day deadline.
- Boundless Agents accepts Web, mobile, chat, or other natural product forms.
- Web is easier to run, record, review, and reproduce.

Recommended architecture:

```text
React/Vite Web frontend
  -> FastAPI backend
  -> SQLite
  -> arXiv source adapter
  -> session/check-in/history APIs
```

The existing iOS app remains the long-term personal app direction, but it should not block competition delivery.

## 9. Reuse From Existing Project

Reuse:

- FastAPI backend structure.
- `BaseSession`.
- `WeeklyCoordinator`.
- `ResearchFeederPayload`.
- Check-in schema and repository.
- SQLite persistence.
- Research Feeder mock payload as fallback/demo mode.
- Documentation and product narrative.

Add:

- Web frontend.
- arXiv/public paper source service.
- session status update.
- competition README.
- demo script.

Do not overbuild:

- New generic agent framework.
- Multi-user auth.
- Full mobile parity.
- Heavy crawler infrastructure.

## 10. Submission Narrative

Selected topic:

```text
AI + Education / Vocational Education Agent
```

Short description:

```text
Orbit Engine helps technical professionals turn frontier AI/autonomous-driving research signals into daily executable learning sessions. It calls public paper sources, selects useful materials, creates a structured reading plan, records check-ins, and preserves learning evidence in History.
```

Compliance boundary:

```text
The system is an auxiliary learning and vocational capability-building tool. It does not replace teachers, institutions, hiring decisions, professional career advisors, or formal educational evaluation. Public paper metadata is used from authorized public sources; private career data is local or simulated in the demo.
```
