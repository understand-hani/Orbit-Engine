# Backend API Demo Flow

Last updated: 2026-08-03

Purpose:

```text
Document the Day 2 backend route surface for the mobile-first Orbit Engine demo.
```

## Run Backend

From:

```bash
cd /home/maxh/Agent/GOAI/backend
venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Optional temporary database for smoke testing:

```bash
DATABASE_PATH=/tmp/goai_day2_smoke.db venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
```

## Demo-Critical Endpoints

Health:

```text
GET /api/health
```

Today preview, not persisted:

```text
GET /api/today
```

Today session, persisted or restored:

```text
GET /api/sessions/today
```

Mock session preview:

```text
GET /api/sessions/mock
POST /api/sessions/mock
```

Session detail:

```text
GET /api/sessions/{session_id}
```

Completion and check-in closed loop:

```text
POST /api/sessions/{session_id}/completion/confirm
```

Use this endpoint for the demo check-in, because it updates session status and creates the check-in record in one backend flow.

Request body:

```json
{
  "duration_min": 30,
  "status": "completed",
  "summary": "Finished the demo deep dive task.",
  "key_insight": "Closed loop needs source, guidance, evidence, and history.",
  "next_action": "Connect a real paper source next."
}
```

History:

```text
GET /api/checkins
GET /api/checkins?date=2026-08-03
```

Direct check-in creation:

```text
POST /api/checkins
```

Do not use this as the main demo action unless session status update is handled separately. It only saves the check-in.

## Day 2 Findings

- Backend imports successfully after installing `backend/requirements.txt` into `backend/venv`.
- `GET /api/health`, `GET /api/today`, and `GET /api/sessions/today` returned HTTP 200 in local uvicorn smoke.
- Service-level closed loop works:
  - create or restore today session
  - confirm completion
  - session status becomes `completed`
  - check-in status becomes `completed`
  - `list_checkins` returns the created check-in
- Cross-session localhost curl is limited by the Codex sandbox network namespace. Browser/local validation should be run from the normal host environment.
- `pytest` is not in `requirements.txt`; route smoke used uvicorn/curl and a service-level script instead.

## Web Demo API List

The Day 2 web shell uses:

```text
GET  /api/sessions/today
POST /api/sessions/{session_id}/completion/confirm
GET  /api/checkins
```

The web shell assumes backend base URL:

```text
http://127.0.0.1:8000/api
```

Override in browser console if needed:

```js
localStorage.setItem("orbit_api_base", "http://YOUR_HOST:8000/api")
```
