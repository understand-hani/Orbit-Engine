# Infra Agent Backend

## Run Locally

```bash
cd /home/maxh/Agent/infra/backend
venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Health check:

```text
http://127.0.0.1:8000/api/health
```

## LLM Configuration

The backend defaults to mock mode:

```env
LLM_PROVIDER=mock
```

To enable real AI analysis for JD Intelligence:

Create or edit:

```text
/home/maxh/Agent/infra/backend/.env
```

```env
LLM_PROVIDER=openrouter
OPENROUTER_API_KEY=your_openrouter_api_key_here
OPENROUTER_MODEL=openai/gpt-4o-mini
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
OPENROUTER_TIMEOUT_SEC=20
OPENROUTER_SITE_URL=
```

The first OpenRouter-backed flow is:

```text
JDEntry + SkillStackSnapshot + TaskStateSnapshot
  -> OpenRouter Chat Completions structured JSON
  -> JDFitAnalysis + CandidateActions
```

Use an OpenRouter model that supports `response_format` with `json_schema`.
If the OpenRouter request fails or the API key is missing, the service falls
back to the existing mock JD analysis so the iOS flow remains usable.

The backend always reads `backend/.env`; do not put the API key in `.env.example`
and do not commit `.env`.

## Signal Radar search

Signal Radar uses Bocha Web Search for current news and organisation/product
updates. Add the key only to `backend/.env`:

```env
BOCHA_API_KEY=your_bocha_api_key_here
```

The key is never committed. Without it, Signal Radar returns no external
results rather than falling back to browser scraping.
