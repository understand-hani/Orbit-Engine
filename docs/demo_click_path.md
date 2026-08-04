# Demo Click Path

Last updated: 2026-08-04

Purpose:

```text
Provide the exact Day 3 mobile web click path for recording and debugging:
Today -> Deep Dive Workspace -> Check-in -> History.
```

## Start Backend

```bash
cd /home/maxh/Agent/GOAI/backend
venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## Open Web Demo

For local browser:

```text
/home/maxh/Agent/GOAI/web/index.html
```

For phone browser on the same network, serve the static directory:

```bash
cd /home/maxh/Agent/GOAI/web
python3 -m http.server 8088 --bind 0.0.0.0
```

Then open:

```text
http://<host-ip>:8088
```

If backend runs on another host/IP, set this once in browser console:

```js
localStorage.setItem("orbit_api_base", "http://<host-ip>:8000/api")
```

## Fixed Demo Session

The Day 3 web demo intentionally uses:

```text
2026-08-06
```

Reason:

```text
2026-08-06 is a Thursday, which maps to the research_feeder / Deep Dive session in the existing weekly coordinator.
This avoids the demo changing behavior based on the real calendar date.
```

## Click Path

1. Open the web page.
2. Confirm the top badge shows `API OK`.
3. Confirm Today shows a `Deep Dive` session.
4. Tap `打开 Workspace`.
5. Inspect:
   - session title
   - current task
   - reading goal
   - why selected
   - 30 / 60 / 90 min path
   - completion criteria
6. Keep the default Check-in text or edit it.
7. Tap `完成并写入 History`.
8. Confirm:
   - Today status becomes `completed`
   - Loop Evidence shows completed state
   - History displays the new check-in without manual database editing

## Expected API Calls

```text
GET  /api/sessions/today?date=2026-08-06
POST /api/sessions/{session_id}/completion/confirm
GET  /api/checkins
```

## Day 3 Boundary

This is still the mock-data closed loop. Real arXiv/public source integration belongs to Day 4.
