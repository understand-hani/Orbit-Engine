# 圆周引擎 / Orbit Engine

GOAI Boundless Agents competition workspace.

## Product Direction

Orbit Engine is a mobile-first web Agent for recurring field exploration and vocational capability building.

Users define a long-term field, follow a recurring weekly rhythm, complete structured Agent sessions, check in, and preserve progress history for the next cycle.

Current target track:

```text
GOAI Boundless Agents
AI + Education / Vocational Education
```

## Workspace Layout

```text
backend/      FastAPI backend copied from the personal Infra Agent project
ios/          Existing SwiftUI prototype copied for reference and long-term app direction
docs/         Competition product definition and execution plan
memory/       Project memory for future Codex sessions
submission/   Submission-facing positioning and demo script
```

## Important Product Split

The original personal app is iOS-first and broader:

```text
Personal Infra Agent
  -> Today / JD / Research / Resume / History
  -> long-term self-use app
```

The competition product is narrower and Web-first:

```text
Orbit Engine
  -> mobile-first web demo
  -> recurring field exploration
  -> first demo loop: public paper source -> Deep Dive -> check-in -> History
```

Do not let native iOS build work block the 8/16 submission.

## Backend

Run locally:

```bash
cd backend
python3 -m venv venv
venv/bin/pip install -r requirements.txt
venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Health check:

```text
http://127.0.0.1:8000/api/health
```

The copied backend intentionally excludes:

- `backend/.env`
- Python caches
- local virtual environments
- local database files

## iOS Prototype

The `ios/` directory is copied for reference and long-term product continuity.

For the competition deadline, the primary demo surface should be:

```text
mobile-first Web / PWA-ready Web
```

## Next Implementation Step

Create the competition frontend:

```text
web/
  index.html
  app.js
  style.css
```

The first web demo should show:

```text
Today
  -> Generate Research Session
  -> Open Deep Dive Workspace
  -> Submit Check-in
  -> History
```

Use existing FastAPI APIs where possible, and add only the smallest backend changes needed for a reliable demo.
