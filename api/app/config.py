from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env.local", extra="ignore")

    gemini_api_key: str
    gemini_model: str = "gemini-3-flash-preview"
    # gemini_model: str = "gemini-3.1-flash-lite-preview"


settings = Settings()  # type: ignore[call-arg]
