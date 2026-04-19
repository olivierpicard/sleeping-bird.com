from typing import TypeVar
import json

from google import genai
from google.genai import types
from pydantic import BaseModel

from app.config import settings

T = TypeVar("T", bound=BaseModel)

_client = genai.Client(api_key=settings.gemini_api_key)


class EmptyResponseError(RuntimeError):
    """Raised when Gemini returns no text payload."""


async def generate_response(
    *,
    user_prompt: str,
    system_prompt: str,
    response_model: type[T],
) -> T:
    response = await _client.aio.models.generate_content(
        model=settings.gemini_model,
        contents=user_prompt,
        config=types.GenerateContentConfig(
            system_instruction=system_prompt,
            thinking_config=types.ThinkingConfig(thinking_level="MINIMAL"),
            response_mime_type="application/json",
            response_json_schema=response_model.model_json_schema(by_alias=True),
        ),
    )

    if not response.text:
        raise EmptyResponseError("The generated response is empty. It is not allowed.")
    return response_model.model_validate_json(response.text)
