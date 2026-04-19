# Sleeping Bird API (FastAPI)

Python port of the Hono API. Exposes Gemini-powered metric-suggestion generation with
a Pydantic-validated response schema and auto-generated OpenAPI docs.

## Setup

```bash
uv sync                 # or: pip install -e .
cp .env.local.example .env.local   # set GEMINI_API_KEY
```

## Run

```bash
uv run uvicorn app.main:app --reload --env-file .env.local
```

- `GET /` — health check
- `GET /generate?prompt=...` — Gemini-generated suggestions
- `GET /openapi.json` — OpenAPI document (served by FastAPI)
- `GET /docs` — Swagger UI

## Export the OpenAPI schema

```bash
uv run python -m scripts.generate_schema
```

Writes `openapi.json` to the project root.
