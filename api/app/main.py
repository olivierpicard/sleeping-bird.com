import logging

from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import PlainTextResponse

from app.schemas import ErrorResponse, GenerateResponse, SuggestionsSchema
from app.services.gemini import generate_response

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """
  You are a specialized Data Architect for health and productivity tracking. Your sole purpose is to parse user dictations and map them into the provided JSON schema.

### Mapping Logic:
1. **Intelligence**: Translate vague intent into specific constraints.
   - If a user says "Scale of 1 to 10", set 'min: 1', 'max: 10', 'granularity: 1', 'kind: "number"'.
   - If a user says "Did I...", use 'kind: "binary"'.


### Constraints:
- Never infer a goal automatically. Fill the goal only when it is explicitly defined by the user
- For duration respect the 'granularity' (ms, s, m, h) as the "floor" for input.
- ONLY available "kind" types are: "number", "categorySingle", "categoryMultiple", "binary", "dateTime", "duration"
"""

app = FastAPI(
    title="Sleeping Bird API",
    version="1.0.0",
    openapi_url="/openapi.json",
)


@app.get("/", response_class=PlainTextResponse)
async def root() -> str:
    return "Hello FastAPI!"


@app.get(
    "/generate",
    response_model=GenerateResponse,
    responses={
        400: {"model": ErrorResponse, "description": "Missing prompt parameter"},
        500: {"model": ErrorResponse, "description": "Gemini API error"},
    },
    summary="Generated metric suggestions",
)
async def generate(
    prompt: str = Query(..., description="User prompt to generate a metric suggestion"),
) -> GenerateResponse:
    try:
        suggestions = await generate_response(
            user_prompt=prompt,
            system_prompt=SYSTEM_PROMPT,
            response_model=SuggestionsSchema,
        )
    except Exception:
        logger.exception("Gemini API error")
        raise HTTPException(status_code=500, detail="Failed to generate response")

    return GenerateResponse(response=suggestions)


# if __name__ == "__main__":
#     import uvicorn

#     uvicorn.run("main:app", host="0.0.0.0", port=5001, reload=True)
