# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
uv sync

# Run development server
uv run uvicorn app.main:app --reload --env-file .env.local

# Lint
uv run ruff check app/
uv run ruff format app/

# Export OpenAPI schema
uv run python -m scripts.generate_schema
```

## Environment

Requires a `.env.local` file with:
- `GEMINI_API_KEY` — Google Gemini API key

## Architecture

Single-purpose FastAPI service: accepts a natural-language prompt, sends it to Gemini with a structured health/productivity data-architect system prompt, and returns 1–3 tracker suggestions as validated JSON.

**Request flow:**
```
GET /generate?prompt=... → main.py → services/gemini.py → Google Gemini API
                                                        ↓
                         GenerateResponse ← SuggestionsSchema (Pydantic-validated)
```

**Key files:**
- `app/main.py` — routes, system prompt, error handling
- `app/services/gemini.py` — async Gemini client, generic typed `generate_response(T)`
- `app/schemas.py` — all Pydantic models; tracker types are a Union of 6 kinds (`NumberTracker`, `CategorySingleTracker`, `CategoryMultipleTracker`, `DurationTracker`, `BinaryTracker`, `DateTimeTracker`)
- `app/config.py` — `Settings` loaded from `.env.local` via pydantic-settings

**Schema conventions:** All models extend `_CamelModel` which auto-serializes snake_case fields to camelCase in JSON output. `additionalProperties = False` is enforced everywhere to keep the LLM output strict.

**Gemini integration:** The client is initialized once at module load in `services/gemini.py`. Responses use Gemini's native JSON mode with the Pydantic schema passed as `response_schema`, then parsed back into typed models.
