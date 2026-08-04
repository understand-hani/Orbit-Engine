# Demo Script

Target length:

```text
60-90 seconds
```

Recommended recording form:

```text
Mobile browser / responsive mobile viewport
```

Purpose:

Show one complete Boundless Agents closed-loop task:

```text
field setup / today session
  -> source/tool call
  -> structured Agent output
  -> user action
  -> check-in
  -> history / validation
```

## 1. Demo Scope

Show only the strongest loop.

Include:

- Mobile-first Today page.
- One selected field: AI / Autonomous Driving Research.
- A Research / Deep Dive session.
- Public paper source or demo source.
- Primary and candidate material cards.
- Why this material matters.
- Structured reading guidance.
- Check-in form.
- Completed or partial session status.
- History showing the new record.

Do not show in the first demo:

- Native iOS app.
- Full JD Intelligence workflow.
- Resume editing.
- PDF annotation persistence.
- Complex settings.
- Agent Infra / AgentTeams claims.

## 2. Suggested Video Flow

### 0-8s: Opening

Screen:

- Phone browser opens Orbit Engine.
- Today page is visible.

Suggested subtitle:

```text
Orbit Engine helps users turn scattered field signals into recurring learning sessions.
```

Show:

- Field: AI / Autonomous Driving Research.
- Today's recommended session: Deep Dive or Research Session.
- Time budget: 30 or 60 minutes.

### 8-22s: Start Today Session

Action:

- Tap `Start Today Session` or `Generate Research Session`.

Show:

- Loading state.
- Source label: arXiv / public paper source.
- Fallback label if demo data is used.

Suggested subtitle:

```text
The Agent prepares today's session from public research signals.
```

### 22-40s: Research Package

Screen:

- Primary paper card.
- Candidate paper card.

Each card should show:

- title
- authors
- source
- published date
- tags
- why selected
- link / PDF link

Suggested subtitle:

```text
Instead of asking the user to search from scratch, the Agent selects a focused material package.
```

### 40-58s: Deep Dive Workspace

Action:

- Open primary material / workspace.

Show structured prompts:

```text
Input / Output
Core method
Evidence to inspect
Relation to my field
Continue / track later / drop
```

Suggested subtitle:

```text
The workspace turns reading into a small executable task.
```

### 58-75s: Check-in

Action:

- Fill short check-in.

Example:

```text
What I did:
Read the abstract and method structure.

Key insight:
The paper is closer to action-conditioned generation than reconstruction.

Next action:
Read the experiment section and compare metrics tomorrow.
```

Submit.

Show:

```text
Session completed
```

or:

```text
Session partial, next action saved
```

### 75-90s: History

Action:

- Open History.

Show:

- today's completed session
- key insight
- next action
- source/paper reference

Suggested closing subtitle:

```text
One closed loop completed: source -> session -> action -> check-in -> history.
```

## 3. Optional Final Frame

Show a simple architecture or text panel:

```text
Mobile-first Web UI
FastAPI backend
BaseSession runtime
Public source adapter
Check-in and History store
```

Keep this under 5 seconds.

## 4. Voiceover Draft

```text
Orbit Engine is a mobile-first Agent for recurring field exploration.
In this demo, the user is building capability in AI and autonomous-driving research.

Instead of starting from a blank search box, the Agent creates today's research session,
calls a public paper source, and prepares a focused material package.

The Deep Dive workspace turns one paper into an executable reading task:
what to understand, what evidence to inspect, and how it connects to the user's field.

After the task, the user submits a short check-in.
The session status is updated, and the result is preserved in History for the next cycle.

This is not a todo app. It is a recurring learning loop:
source, session, action, check-in, and history.
```

## 5. Demo Checklist

Before recording, verify:

- Mobile viewport works at 375px width.
- Text does not overflow.
- Buttons are easy to tap.
- Backend is reachable from browser.
- Demo data or arXiv data loads reliably.
- Check-in submit succeeds.
- History updates without manual database editing.
- Any fallback/mock source is clearly labeled.

## 6. If Real arXiv Source Is Not Ready

Use demo data, but label it clearly:

```text
Demo source: public-paper-like sample data.
```

Do not pretend mock data is live arXiv.

The video can still show the closed-loop task, while the PPT/README states that live arXiv integration is the immediate next step.
